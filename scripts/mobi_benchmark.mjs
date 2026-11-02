import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {copyFile, cp, mkdir, mkdtemp, readdir, readFile, stat, writeFile} from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const protocol = 'mobi-decoder-batch-v1';
const sha256 = value => createHash('sha256').update(value).digest('hex');

export function statistics(samples) {
  if (!samples.length || samples.some(n => !Number.isFinite(n) || n < 0)) {
    throw new Error('Invalid timing samples');
  }
  const sorted = [...samples].sort((a, b) => a - b);
  return {median: sorted[Math.floor(sorted.length / 2)], p95: sorted[Math.ceil(sorted.length * .95) - 1]};
}

export function validateWorker(result, input, sampling) {
  const bytes = field => input[field].reduce((n, record) => n + Buffer.from(record, 'base64').length, 0);
  if (result.protocol !== protocol || result.mode !== 'aot' || result.verified !== true ||
      typeof result.implementation !== 'string' || !result.implementation ||
      typeof result.runtime !== 'string' || !result.runtime || result.caseId !== input.id ||
      result.records !== input.records.length || result.inputBytes !== bytes('records') ||
      result.outputBytes !== bytes('expected') || result.samplesUs?.length !== sampling.samples ||
      !Number.isFinite(result.setupUs) || result.setupUs < 0 ||
      !Number.isFinite(result.firstBatchUs) || result.firstBatchUs < 0 ||
      !Number.isFinite(result.processPeakRssBytes) || result.processPeakRssBytes <= 0) {
    throw new Error(`Invalid or unverified worker result for ${input.id}`);
  }
  statistics(result.samplesUs);
}

function validateReport(report) {
  if (report.status !== 'complete' || report.protocol !== protocol ||
      !report.cases?.length || !report.datasetSha256 || !report.machine?.fingerprint ||
      !report.sampling || !report.runtime || !report.implementation ||
      !['samples', 'warmups', 'processes'].every(k => Number.isInteger(report.sampling[k])) ||
      report.sampling.samples < 20 || report.sampling.processes < 1 || report.sampling.warmups < 1 ||
      new Set(report.cases.map(c => c.id)).size !== report.cases.length) {
    throw new Error('Incomplete benchmark report');
  }
  for (const input of report.cases) {
    if (!input.id || !/^[0-9a-f]{64}$/.test(input.outputSha256 ?? '') ||
        !Number.isInteger(input.records) || input.records < 1 ||
        !Number.isInteger(input.inputBytes) || input.inputBytes < 0 ||
        !Number.isInteger(input.outputBytes) || input.outputBytes < 0) throw new Error('Invalid case metadata');
    if (input.runs?.length !== report.sampling.processes) throw new Error('Incomplete worker runs');
    for (const run of input.runs) {
      if (run.verified !== true || run.mode !== 'aot' || run.protocol !== protocol ||
          run.caseId !== input.id || run.runtime !== report.runtime ||
          run.records !== input.records || run.inputBytes !== input.inputBytes || run.outputBytes !== input.outputBytes ||
          run.implementation !== report.implementation ||
          run.samplesUs?.length !== report.sampling.samples ||
          !Number.isFinite(run.setupUs) || run.setupUs < 0 ||
          !Number.isFinite(run.firstBatchUs) || run.firstBatchUs < 0 ||
          !Number.isFinite(run.processPeakRssBytes) || run.processPeakRssBytes <= 0) {
        throw new Error('Incomplete or unverified worker run');
      }
      statistics(run.samplesUs);
    }
  }
}

export function compareReports(baseline, candidate) {
  validateReport(baseline);
  validateReport(candidate);
  for (const key of ['datasetSha256', 'runtime']) {
    if (baseline[key] !== candidate[key]) throw new Error(`Incompatible ${key}`);
  }
  if (baseline.machine.fingerprint !== candidate.machine.fingerprint) throw new Error('Different machines');
  for (const key of ['samples', 'warmups', 'processes']) {
    if (baseline.sampling[key] !== candidate.sampling[key]) throw new Error(`Different sampling: ${key}`);
  }
  if (baseline.cases.length !== candidate.cases.length) throw new Error('Different cases');
  return baseline.cases.map(a => {
    const b = candidate.cases.find(c => c.id === a.id);
    if (!b || a.outputSha256 !== b.outputSha256 || a.records !== b.records ||
        a.inputBytes !== b.inputBytes || a.outputBytes !== b.outputBytes || a.compression !== b.compression) {
      throw new Error(`Different input or output for ${a.id}`);
    }
    function summary(input) {
      const warm = statistics(input.runs.flatMap(r => r.samplesUs));
      return {
        coldMs: statistics(input.runs.map(r => r.setupUs + r.firstBatchUs)).median / 1000,
        medianMs: warm.median / 1000, p95Ms: warm.p95 / 1000,
        mibPerSecond: warm.median === 0 ? null : input.outputBytes / 1048576 / (warm.median / 1e6),
        peakRssMiB: Math.max(...input.runs.map(r => r.processPeakRssBytes)) / 1048576,
      };
    }
    const before = summary(a);
    const after = summary(b);
    return {id: a.id, before, after, speedup: after.medianMs === 0 ? null : before.medianMs / after.medianMs};
  });
}

function options(args) {
  const out = {books: [], artifacts: []};
  for (let i = 0; i < args.length; i += 2) {
    const key = args[i];
    const value = args[i + 1];
    if (!key?.startsWith('--') || value === undefined) throw new Error('Expected --option value pairs');
    if (key === '--book') out.books.push(value);
    else if (key === '--artifact') out.artifacts.push(value);
    else if (['--dataset', '--worker', '--bundle', '--library', '--label', '--samples', '--warmups', '--processes', '--output-dir'].includes(key)) out[key.slice(2)] = value;
    else throw new Error(`Unknown option: ${key}`);
  }
  return out;
}

function invoke(program, args, env = process.env) {
  return execFileSync(program, args, {cwd: root, env, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024});
}

async function bundleFiles(directory) {
  const files = [];
  for (const entry of await readdir(directory, {withFileTypes: true})) {
    const file = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...await bundleFiles(file));
    else if (entry.isFile()) files.push(file);
    else throw new Error(`Unsupported bundle entry: ${file}`);
  }
  return files.sort();
}

async function run(command, opts) {
  const sampling = {samples: Number(opts.samples ?? 21), warmups: Number(opts.warmups ?? 5), processes: Number(opts.processes ?? 3)};
  if (!Object.values(sampling).every(Number.isInteger) || sampling.samples < 20 || sampling.warmups < 1 || sampling.processes < 1) {
    throw new Error('Use >=20 samples, >=1 warmup and >=1 process');
  }
  const label = opts.label ?? (command === 'baseline' ? 'dart-aot' : 'candidate');
  if (!/^[a-zA-Z0-9_-]+$/.test(label)) throw new Error('Label must contain only letters, digits, _ and -');
  const parent = path.resolve(root, opts['output-dir'] ?? '.local/performance/mobi');
  await mkdir(parent, {recursive: true});
  const directory = await mkdtemp(path.join(parent, `${label}-`));
  const artifacts = [];
  const env = {...process.env};
  let worker;
  let dataset;
  if (command === 'baseline') {
    const name = process.platform === 'win32' ? 'mobi_decoder_benchmark.exe' : 'mobi_decoder_benchmark';
    const bundle = path.join(directory, 'bundle');
    worker = path.join(bundle, 'bin', name);
    const [dart, ...prefix] = (process.env.DART ?? 'fvm dart').trim().split(/\s+/);
    process.stderr.write('Compiling Dart reference decoder in AOT...\n');
    invoke(dart, [...prefix, 'build', 'cli', '--target', 'bin/mobi_decoder_benchmark.dart', '--output', directory]);
    artifacts.push(...(await bundleFiles(bundle)).filter(file => file !== worker));
    dataset = path.join(directory, 'dataset.json');
    const books = opts.books.length ? opts.books : ['packages/vellum/test/fixtures/mobi/six.mobi'];
    invoke(worker, ['prepare', dataset, ...books]);
  } else {
    if (!opts.worker || !opts.dataset) throw new Error('run needs --worker and --dataset');
    const originalWorker = path.resolve(root, opts.worker);
    if (opts.bundle) {
      const originalBundle = path.resolve(root, opts.bundle);
      const relative = path.relative(originalBundle, originalWorker);
      if (!relative || relative.startsWith('..') || path.isAbsolute(relative)) throw new Error('Worker must be inside the bundle');
      const bundle = path.join(directory, 'bundle');
      await cp(originalBundle, bundle, {recursive: true, force: false, errorOnExist: true});
      worker = path.join(bundle, relative);
      artifacts.push(...(await bundleFiles(bundle)).filter(file => file !== worker));
    } else {
      worker = path.join(directory, `worker${path.extname(originalWorker)}`);
      await copyFile(originalWorker, worker);
    }
    const original = await readFile(path.resolve(root, opts.dataset));
    dataset = path.join(directory, 'dataset.json');
    await writeFile(dataset, original, {flag: 'wx'});
  }
  for (const file of [...opts.artifacts, ...(opts.library ? [opts.library] : [])]) {
    const original = path.resolve(root, file);
    const copy = path.join(directory, `artifact-${artifacts.length}-${path.basename(original)}`);
    await copyFile(original, copy);
    artifacts.push(copy);
    if (file === opts.library) env.MOBI_RUST_LIBRARY = copy;
  }
  const datasetBytes = await readFile(dataset);
  const inputs = JSON.parse(datasetBytes);
  if (inputs.protocol !== protocol || !inputs.cases?.length) throw new Error('Invalid dataset');
  const machine = {
    platform: os.platform(), arch: os.arch(), release: os.release(),
    cpu: os.cpus()[0]?.model, logicalCpus: os.cpus().length, memoryBytes: os.totalmem(),
  };
  machine.fingerprint = sha256(JSON.stringify({...machine, host: os.hostname()}));
  const report = {
    status: 'complete', protocol, label, createdAt: new Date().toISOString(),
    datasetSha256: sha256(datasetBytes), machine, sampling,
    scope: 'host AOT, in-memory decoder batches; excludes file I/O, UI, process startup and library initialization',
    execution: {worker: path.relative(directory, worker), nativeLibrary: opts.library ? path.relative(directory, env.MOBI_RUST_LIBRARY) : null},
    cases: [], artifacts: [],
  };
  for (const input of inputs.cases) {
    process.stderr.write(`Measuring ${input.id} (${sampling.processes} fresh processes)...\n`);
    const runs = [];
    for (let i = 0; i < sampling.processes; i++) {
      const result = JSON.parse(invoke(worker, [dataset, input.id, `${sampling.samples}`, `${sampling.warmups}`], env));
      validateWorker(result, input, sampling);
      report.runtime ??= result.runtime;
      report.implementation ??= result.implementation;
      if (report.runtime !== result.runtime || report.implementation !== result.implementation) throw new Error('Worker identity changed');
      runs.push(result);
    }
    report.cases.push({
      id: input.id, source: input.source, compression: input.compression,
      records: runs[0].records, inputBytes: runs[0].inputBytes, outputBytes: runs[0].outputBytes,
      outputSha256: sha256(JSON.stringify(input.expected)), runs,
    });
  }
  for (const file of [worker, ...artifacts]) {
    report.artifacts.push({name: path.relative(directory, file), bytes: (await stat(file)).size, sha256: sha256(await readFile(file))});
  }
  validateReport(report);
  const output = path.join(directory, 'report.json');
  await writeFile(output, `${JSON.stringify(report, null, 2)}\n`, {flag: 'wx'});
  process.stdout.write(`${output}\n`);
}

async function main() {
  const [command, ...args] = process.argv.slice(2);
  if (command === 'compare') {
    if (args.length !== 2) throw new Error('compare needs baseline.json candidate.json');
    const [a, b] = await Promise.all(args.map(p => readFile(p, 'utf8').then(JSON.parse)));
    const rows = compareReports(a, b);
    process.stdout.write(`| Case | Warm median ms (${a.label} → ${b.label}) | p95 ms | Speedup | Peak process RSS MiB |\n|---|---:|---:|---:|---:|\n`);
    const f = n => n === null ? 'n/a' : n.toFixed(3);
    for (const r of rows) process.stdout.write(`| ${r.id} | ${f(r.before.medianMs)} → ${f(r.after.medianMs)} | ${f(r.before.p95Ms)} → ${f(r.after.p95Ms)} | ${f(r.speedup)}× | ${f(r.before.peakRssMiB)} → ${f(r.after.peakRssMiB)} |\n`);
    process.stdout.write('Cold/setup samples, throughput inputs and artifact sizes remain in the JSON reports.\n');
  } else if (command === 'baseline' || command === 'run') {
    await run(command, options(args));
  } else {
    throw new Error('Use baseline [options], run --dataset ... --worker ..., or compare baseline.json candidate.json');
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch(error => { process.stderr.write(`${error.stack}\n`); process.exitCode = 1; });
}
