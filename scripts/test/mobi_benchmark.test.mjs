import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdir, mkdtemp, readFile, rm, writeFile} from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import {compareReports, statistics, validateWorker} from '../mobi_benchmark.mjs';

function report(implementation = 'dart', times = [100, 200, 300]) {
  const samples = Array.from({length: 21}, (_, i) => times[i % times.length]);
  return {
    status: 'complete', protocol: 'mobi-decoder-batch-v1', label: implementation,
    datasetSha256: 'a'.repeat(64), runtime: 'same-sdk', implementation,
    machine: {fingerprint: 'same-machine'}, sampling: {samples: 21, warmups: 5, processes: 1},
    cases: [{
      id: 'case', compression: 2, records: 1, inputBytes: 10, outputBytes: 20,
      outputSha256: 'b'.repeat(64),
      runs: [{
        protocol: 'mobi-decoder-batch-v1', mode: 'aot', caseId: 'case',
        implementation, runtime: 'same-sdk', verified: true,
        records: 1, inputBytes: 10, outputBytes: 20,
        setupUs: 10, firstBatchUs: 500, samplesUs: samples, processPeakRssBytes: 1048576,
      }],
    }],
  };
}

test('compares complete matching runs without modifying timing samples', () => {
  const baseline = report();
  const candidate = report('rust-frb', [50, 100, 150]);
  const before = structuredClone(baseline);
  const [row] = compareReports(baseline, candidate);
  assert.equal(row.speedup, 2);
  assert.equal(row.before.medianMs, .2);
  assert.equal(row.after.p95Ms, .15);
  assert.deepEqual(baseline, before);
});

test('rejects different input, output, runtime, machine and sampling', () => {
  for (const mutate of [
    r => { r.datasetSha256 = 'c'.repeat(64); },
    r => { r.cases[0].outputSha256 = 'c'.repeat(64); },
    r => { r.runtime = 'other-sdk'; },
    r => { r.machine.fingerprint = 'other-machine'; },
    r => { r.sampling.warmups = 10; },
    r => { r.cases[0].compression = 17480; },
  ]) {
    const candidate = report();
    mutate(candidate);
    assert.throws(() => compareReports(report(), candidate));
  }
});

test('rejects partial, unverified and JIT runs', () => {
  for (const mutate of [
    r => { r.status = 'running'; },
    r => { r.cases[0].runs = []; },
    r => { r.cases[0].runs[0].verified = false; },
    r => { r.cases[0].runs[0].mode = 'jit'; },
    r => { r.cases[0].runs[0].samplesUs.pop(); },
    r => { r.cases[0].runs[0].records++; },
    r => { r.cases.push(structuredClone(r.cases[0])); },
  ]) {
    const candidate = report();
    mutate(candidate);
    assert.throws(() => compareReports(report(), candidate));
  }
});

test('worker evidence must match the frozen dataset and sample count', () => {
  const input = {id: 'case', records: [Buffer.alloc(10).toString('base64')], expected: [Buffer.alloc(20).toString('base64')]};
  const result = report().cases[0].runs[0];
  assert.doesNotThrow(() => validateWorker(result, input, {samples: 21}));
  assert.throws(() => validateWorker({...result, outputBytes: 21}, input, {samples: 21}));
  assert.throws(() => validateWorker({...result, samplesUs: [NaN]}, input, {samples: 1}));
});

test('percentiles use raw samples and reject corrupt timings', () => {
  assert.deepEqual(statistics([30, 10, 20]), {median: 20, p95: 30});
  for (const samples of [[], [NaN], [-1], [Infinity]]) assert.throws(() => statistics(samples));
});

test('CLI freezes the worker bundle, library and dataset before running', async () => {
  const directory = await mkdtemp(path.join(os.tmpdir(), 'mobi-benchmark-test-'));
  try {
    const bundle = path.join(directory, 'original/bundle');
    await mkdir(path.join(bundle, 'bin'), {recursive: true});
    await mkdir(path.join(bundle, 'lib'));
    const worker = path.join(bundle, 'bin/worker.mjs');
    const library = path.join(directory, 'original/native-library');
    const asset = path.join(bundle, 'lib/asset');
    const dataset = path.join(directory, 'dataset.json');
    await writeFile(library, 'original native library');
    await writeFile(asset, 'original bundled asset');
    await writeFile(dataset, JSON.stringify({protocol: 'mobi-decoder-batch-v1', cases: [{
      id: 'case', source: 'test stub', compression: 2, records: ['YQ=='], expected: ['YQ=='],
    }]}));
    // This stub tests orchestration only; its timings are never performance evidence.
    const source = `#!/usr/bin/env node
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
assert.notEqual(process.env.MOBI_RUST_LIBRARY, ${JSON.stringify(library)});
assert.equal(readFileSync(process.env.MOBI_RUST_LIBRARY, 'utf8'), 'original native library');
console.log(JSON.stringify({
  protocol: 'mobi-decoder-batch-v1', mode: 'aot', verified: true,
  implementation: 'test-stub', runtime: 'test-sdk', caseId: 'case',
  records: 1, inputBytes: 1, outputBytes: 1, setupUs: 0, firstBatchUs: 1,
  samplesUs: Array(Number(process.argv[4])).fill(1), processPeakRssBytes: 1,
}));
`;
    await writeFile(worker, source, {mode: 0o755});
    const resultPath = execFileSync(process.execPath, ['scripts/mobi_benchmark.mjs', 'run',
      '--label', 'test', '--dataset', dataset, '--worker', worker, '--bundle', bundle,
      '--library', library, '--samples', '20', '--warmups', '1', '--processes', '1',
      '--output-dir', path.join(directory, 'reports'),
    ], {encoding: 'utf8'}).trim();
    const result = JSON.parse(await readFile(resultPath, 'utf8'));
    const frozen = path.dirname(resultPath);
    await writeFile(worker, 'changed worker');
    await writeFile(library, 'changed library');
    await writeFile(asset, 'changed asset');
    await writeFile(dataset, 'changed dataset');
    assert.equal(await readFile(path.join(frozen, result.execution.worker), 'utf8'), source);
    assert.equal(await readFile(path.join(frozen, result.execution.nativeLibrary), 'utf8'), 'original native library');
    assert.equal(await readFile(path.join(frozen, 'bundle/lib/asset'), 'utf8'), 'original bundled asset');
    assert.equal(JSON.parse(await readFile(path.join(frozen, 'dataset.json'), 'utf8')).cases[0].id, 'case');
    assert.equal(result.artifacts.length, 3);
    assert.equal(result.status, 'complete');
  } finally {
    await rm(directory, {recursive: true, force: true});
  }
});
