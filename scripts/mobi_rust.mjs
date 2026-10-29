import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {copyFile, mkdir, mkdtemp, readFile, writeFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const packageRoot = path.join(root, 'benchmarks/mobi_rust');
const rustRoot = path.join(packageRoot, 'rust');
const [dart, ...dartPrefix] = (process.env.DART ?? 'fvm dart').trim().split(/\s+/);
const libraryName = {
  darwin: 'libvellum_mobi_benchmark.dylib',
  linux: 'libvellum_mobi_benchmark.so',
  win32: 'vellum_mobi_benchmark.dll',
}[process.platform];

function invoke(program, args, cwd = packageRoot, env = process.env) {
  execFileSync(program, args, {cwd, env, stdio: 'inherit'});
}

async function build(compileWorker = true) {
  if (!libraryName) throw new Error(`Unsupported host: ${process.platform}`);
  // A fixed target directory makes the artifact location independent of shell overrides.
  invoke('cargo', ['build', '--locked', '--release', '--target-dir', 'target'], rustRoot);
  const parent = path.join(root, '.local/performance/mobi-rust');
  await mkdir(parent, {recursive: true});
  const directory = await mkdtemp(path.join(parent, 'build-'));
  const library = path.join(directory, libraryName);
  const worker = path.join(directory, 'bundle/bin', process.platform === 'win32' ? 'mobi_rust_benchmark.exe' : 'mobi_rust_benchmark');
  if (compileWorker) {
    invoke(dart, [...dartPrefix, 'build', 'cli', '--target', 'bin/mobi_rust_benchmark.dart', '--output', directory]);
  }
  await copyFile(path.join(rustRoot, 'target/release', libraryName), library);
  const sources = {};
  for (const file of ['pubspec.lock', 'flutter_rust_bridge.yaml', 'rust/Cargo.toml', 'rust/Cargo.lock', 'rust/src/api.rs', 'rust/src/decoder.rs', 'rust/src/frb_generated.rs', 'bin/mobi_rust_backend.dart', 'bin/mobi_rust_benchmark.dart', '../mobi_decoder_benchmark.dart', '../mobi_huff_fixture.dart']) {
    sources[file] = createHash('sha256').update(await readFile(path.join(packageRoot, file))).digest('hex');
  }
  const manifest = path.join(directory, 'build.json');
  await writeFile(manifest, `${JSON.stringify({
    rustc: execFileSync('rustc', ['--version', '--verbose'], {encoding: 'utf8'}).trim(),
    profile: 'release', flutterRustBridge: '2.13.0',
    bridgeConfiguration: await readFile(path.join(packageRoot, 'flutter_rust_bridge.yaml'), 'utf8'),
    sources,
  }, null, 2)}\n`, {flag: 'wx'});
  return {worker, bundle: compileWorker ? path.join(directory, 'bundle') : undefined, library, manifest};
}

async function main() {
  const [command, ...args] = process.argv.slice(2);
  if (command === 'build' && !args.length) {
    process.stdout.write(`${JSON.stringify(await build())}\n`);
  } else if (command === 'test' && !args.length) {
    invoke('cargo', ['fmt', '--check'], rustRoot);
    invoke('cargo', ['clippy', '--locked', '--all-targets', '--', '-D', 'warnings'], rustRoot);
    invoke('cargo', ['test', '--locked'], rustRoot);
    const {library} = await build(false);
    invoke(dart, [...dartPrefix, 'analyze', 'bin', 'test'], packageRoot);
    invoke(dart, [...dartPrefix, 'test', '--reporter', 'expanded'], packageRoot, {...process.env, MOBI_RUST_LIBRARY: library});
  } else if (command === 'benchmark' && args.includes('--dataset')) {
    const {worker, bundle, library, manifest} = await build();
    invoke(process.execPath, ['scripts/mobi_benchmark.mjs', 'run', '--label', 'rust-frb', ...args, '--worker', worker, '--bundle', bundle, '--library', library, '--artifact', manifest], root);
  } else {
    throw new Error('Use build, test, or benchmark --dataset <frozen-dataset.json> [runner options]');
  }
}

main().catch(error => { process.stderr.write(`${error.stack}\n`); process.exitCode = 1; });
