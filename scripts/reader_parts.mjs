import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {copyFile, cp, mkdir, mkdtemp, readFile, readdir, writeFile} from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const [datasetArg, bundleArg, libraryArg] = process.argv.slice(2);
if (!datasetArg || !bundleArg || !libraryArg || process.argv.length !== 5) {
  throw new Error('Use node scripts/reader_parts.mjs <dataset.json> <AOT bundle> <release library>');
}
const sha256 = data => createHash('sha256').update(data).digest('hex');
const parent = path.join(root, '.local/performance/reader-parts');
await mkdir(parent, {recursive: true});
const directory = await mkdtemp(path.join(parent, 'comparison-'));
await cp(path.resolve(bundleArg), path.join(directory, 'bundle'), {recursive: true});
const library = path.join(directory, path.basename(libraryArg));
await copyFile(path.resolve(libraryArg), library);
const data = JSON.parse(await readFile(datasetArg, 'utf8'));
if (data.protocol !== 'reader-parts-v1') throw new Error('Dataset protocol differs');
const dataDirectory = path.join(directory, 'data');
await mkdir(dataDirectory);
for (const [file, hash] of Object.entries(data.files)) {
  if (file !== path.basename(file)) throw new Error('Expected flat dataset files');
  const bytes = await readFile(path.join(path.dirname(datasetArg), file));
  if (sha256(bytes) !== hash) throw new Error(`Input hash differs: ${file}`);
  await writeFile(path.join(dataDirectory, file), bytes, {flag: 'wx'});
}
const dataset = path.join(dataDirectory, 'dataset.json');
await copyFile(datasetArg, dataset);
const artifacts = {};
async function hashTree(dir, prefix = '') {
  for (const item of await readdir(dir, {withFileTypes: true})) {
    const relative = path.join(prefix, item.name);
    if (item.isDirectory()) await hashTree(path.join(dir, item.name), relative);
    else artifacts[relative] = sha256(await readFile(path.join(dir, item.name)));
  }
}
await hashTree(path.join(directory, 'bundle'), 'bundle');
artifacts[path.basename(library)] = sha256(await readFile(library));
artifacts['dataset.json'] = sha256(await readFile(dataset));
const sources = {};
async function hashSources(relative) {
  const absolute = path.join(root, relative);
  const entries = await readdir(absolute, {withFileTypes: true});
  for (const entry of entries) {
    const child = path.join(relative, entry.name);
    if (entry.isDirectory()) await hashSources(child);
    else sources[child] = sha256(await readFile(path.join(root, child)));
  }
}
for (const directory of ['benchmarks/reader_native/bin', 'benchmarks/reader_native/lib',
  'benchmarks/reader_native/rust/src', 'packages/vellum/lib',
  'packages/vellum/rust/src', 'packages/vellum/hook']) await hashSources(directory);
for (const file of ['benchmarks/reader_native/pubspec.lock',
  'benchmarks/reader_native/flutter_rust_bridge.yaml',
  'benchmarks/reader_native/rust/Cargo.toml', 'benchmarks/reader_native/rust/Cargo.lock',
  'packages/vellum/pubspec.yaml', 'packages/vellum/pubspec.lock',
  'packages/vellum/rust/Cargo.toml', 'packages/vellum/rust/Cargo.lock',
  'packages/vellum/rust/rust-toolchain.toml', 'packages/vellum/flutter_rust_bridge.yaml',
  'benchmarks/mobi_rust/rust/src/decoder.rs', 'scripts/reader_parts.mjs']) {
  sources[file] = sha256(await readFile(path.join(root, file)));
}
for (const [file, expected] of Object.entries(sources)) {
  const bytes = await readFile(path.join(root, file));
  if (sha256(bytes) !== expected) throw new Error(`Source changed during freezing: ${file}`);
  const target = path.join(directory, 'sources', file);
  await mkdir(path.dirname(target), {recursive: true});
  await writeFile(target, bytes, {flag: 'wx'});
}
const worker = path.join(directory, 'bundle/bin',
  process.platform === 'win32' ? 'reader_parts_benchmark.exe' : 'reader_parts_benchmark');
const runs = [];
const rounds = ['dart', 'rust', 'rust', 'dart'];
const failures = [];
for (let round = 0; round < rounds.length; round++) {
  const implementation = rounds[round];
  for (const job of data.cases) {
    try {
      const output = execFileSync(worker, [dataset, job.id, implementation, '21'], {
        env: {...process.env, READER_BENCHMARK_LIBRARY: library},
        encoding: 'utf8', timeout: 120000, maxBuffer: 1024 * 1024,
        stdio: ['ignore', 'pipe', 'pipe'],
      });
      const result = {...JSON.parse(output), round};
      runs.push(result);
      process.stdout.write(`${round + 1} ${implementation} ${job.id}: ${(result.medianUs / 1000).toFixed(3)} ms\n`);
    } catch (error) {
      const detail = error.stderr?.toString() || error.message;
      failures.push({round, implementation, caseId: job.id, error: detail});
      process.stderr.write(`${implementation} ${job.id}: ${detail.split('\n')[0]}\n`);
    }
  }
  await writeFile(path.join(directory, 'progress.json'), JSON.stringify({runs, failures}, null, 2));
}
const median = values => [...values].sort((a, b) => a - b)[Math.floor(values.length / 2)];
const summary = data.cases.map(job => {
  const backends = Object.fromEntries(['dart', 'rust'].map(implementation => {
    const items = runs.filter(r => r.caseId === job.id && r.implementation === implementation);
    return [implementation, items.length === 2 ? {
      medianUs: median(items.flatMap(r => r.samplesUs)),
      processMediansUs: items.map(r => r.medianUs),
      maxRssBytes: Math.max(...items.map(r => r.maxRssBytes)),
      setupUs: items.map(r => r.setupUs), firstUs: items.map(r => r.firstUs),
    } : null];
  }));
  return {caseId: job.id, ...backends,
    speedup: backends.dart && backends.rust
      ? backends.dart.medianUs / backends.rust.medianUs : null};
});
const report = {
  protocol: data.protocol, createdAt: new Date().toISOString(),
  machine: {platform: process.platform, arch: process.arch, release: os.release(),
    cpu: os.cpus()[0].model, memoryBytes: os.totalmem()},
  rustc: execFileSync('rustc', ['--version', '--verbose'], {encoding: 'utf8'}),
  productionRustc: execFileSync(
    execFileSync('rustup', ['which', 'rustc'], {
      cwd: path.join(root, 'packages/vellum/rust'), encoding: 'utf8',
    }).trim(), ['--version', '--verbose'], {encoding: 'utf8'}),
  order: rounds, samplesPerProcess: 21, warmups: 3,
  artifacts, sourcesAtRun: sources, frozenSources: 'sources/',
  inputs: data.files, cases: data.cases, summary, runs, failures,
};
await writeFile(path.join(directory, 'report.json'), JSON.stringify(report, null, 2));
process.stdout.write(`${path.join(directory, 'report.json')}\n`);
if (failures.length) process.exitCode = 1;
