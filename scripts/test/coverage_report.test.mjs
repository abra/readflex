import assert from 'node:assert/strict';
import {mkdtemp, mkdir, readFile, rm, writeFile} from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import {buildReport, mergeLcov, parseTestEvents, sourceSnapshot, summarize} from '../coverage_report.mjs';

const options = {directory: '/repo/package', packages: new Map([['demo', '/repo/package']])};

test('merges duplicate paths and unions coverage instead of averaging runs', () => {
  const records = mergeLcov('SF:lib/a.dart\nDA:10,1\nDA:11,0\nBRDA:10,0,0,-\nend_of_record', options);
  mergeLcov('SF:package:demo/a.dart\nDA:10,0\nDA:11,3\nBRDA:10,0,0,1\nend_of_record', options, records);
  assert.equal(records.size, 1);
  assert.deepEqual(summarize(records.get('/repo/package/lib/a.dart')), {
    measured: true, linesHit: 2, linesFound: 2, branchesHit: 1, branchesFound: 1,
    uncoveredLines: [], uncoveredBranches: [],
  });
});

test('retains unhit lines and branches, and marks unloaded files unmeasured', () => {
  const records = mergeLcov('SF:lib/a.dart\nDA:10,0\nBRDA:10,0,1,-\nend_of_record', options);
  const measured = summarize(records.get('/repo/package/lib/a.dart'));
  assert.deepEqual(measured.uncoveredLines, [10]);
  assert.deepEqual(measured.uncoveredBranches, ['10,0,1']);
  assert.equal(measured.measured, true);
  assert.equal(summarize(undefined).measured, false);
});

test('accepts file URIs and ignores DA checksums', () => {
  const records = mergeLcov('SF:file:///repo/package/lib/a.dart\nDA:10,2,checksum\nend_of_record', options);
  assert.equal(summarize(records.get('/repo/package/lib/a.dart')).linesHit, 1);
});

test('rejects orphan coverage, unknown packages and malformed counters', () => {
  for (const input of ['DA:1,1', 'SF:package:unknown/a.dart', 'SF:lib/a.dart\nDA:1,NaN']) {
    assert.throws(() => mergeLcov(input, options));
  }
});

test('test evidence excludes hidden setup and retains skips and failures', () => {
  const events = [
    {type: 'suite', suite: {id: 1, path: 'test/a_test.dart'}},
    ...[1, 2, 3].map(id => ({type: 'testStart', test: {id, name: `test-${id}`, suiteID: 1}})),
    {type: 'testDone', testID: 1, hidden: true, skipped: false, result: 'success'},
    {type: 'testDone', testID: 2, hidden: false, skipped: true, result: 'success'},
    {type: 'testDone', testID: 3, hidden: false, skipped: false, result: 'failure'},
    {type: 'done', success: false},
  ];
  const report = parseTestEvents(events.map(value => JSON.stringify(value)).join('\n'));
  assert.equal(report.success, false);
  assert.deepEqual(report.tests.map(test => test.status), ['skipped', 'failure']);
  assert.equal(report.tests[0].file, 'test/a_test.dart');
});

test('an interrupted or corrupt run cannot appear successful', () => {
  assert.throws(() => parseTestEvents(''));
  assert.throws(() => parseTestEvents('{not json}'));
  assert.throws(() => parseTestEvents('{"type":"testDone","testID":1}'));
});

test('done success cannot conceal an unfinished test', () => {
  assert.throws(() => parseTestEvents([
    {type: 'testStart', test: {id: 1, name: 'unfinished'}},
    {type: 'done', success: true},
  ].map(JSON.stringify).join('\n')), /Incomplete test/);
});

async function fixture(t) {
  const root = await mkdtemp(path.join(os.tmpdir(), 'readflex-coverage-'));
  t.after(() => rm(root, {recursive: true, force: true}));
  for (const dir of ['lib', '.dart_tool', 'host/app', 'native']) {
    await mkdir(path.join(root, dir), {recursive: true});
  }
  await writeFile(path.join(root, 'lib/main.dart'), 'void main() {}\n');
  await writeFile(path.join(root, 'pubspec.yaml'), 'name: demo\n');
  await writeFile(path.join(root, '.dart_tool/package_config.json'), JSON.stringify({
    packages: [{name: 'demo', rootUri: '../', packageUri: 'lib/'}],
  }));
  const snapshot = await sourceSnapshot(root);
  for (const dir of ['host', 'native']) {
    await writeFile(path.join(root, dir, 'sources.json'), JSON.stringify(snapshot));
  }
  await writeFile(path.join(root, 'host/suites.tsv'), `app\t${root}\t0\ttrue\n`);
  await writeFile(path.join(root, 'host/completed'), 'complete\n');
  await writeFile(path.join(root, 'host/app/lcov.info'), 'SF:lib/main.dart\nDA:1,0\nBRDA:1,0,0,0\nend_of_record');
  await writeFile(path.join(root, 'host/app/tests.jsonl'), [
    {type: 'suite', suite: {id: 1, path: 'test/demo.dart'}},
    {type: 'testStart', test: {id: 1, suiteID: 1, name: 'host case'}},
    {type: 'testDone', testID: 1, hidden: false, skipped: false, result: 'success'},
    {type: 'done', success: true},
  ].map(JSON.stringify).join('\n'));
  await writeFile(path.join(root, 'native/lcov.info'), 'SF:lib/main.dart\nDA:1,1\nend_of_record');
  await writeFile(path.join(root, 'native/results.json'), JSON.stringify({
    platform: 'ios', completedAt: '2026-09-13T00:00:00Z', tests: {'native case': 'success'},
  }));
  return {root, output: path.join(root, 'host'), native: path.join(root, 'native')};
}

test('native line coverage augments host coverage without fabricating branch hits', async t => {
  const {root, output, native} = await fixture(t);
  const report = await buildReport(root, output, [native]);
  assert.equal(report.successful, true);
  assert.equal(report.packages[0].linesHit, 1);
  assert.equal(report.packages[0].branchesHit, 0);
  assert.equal(report.suites.find(suite => suite.platform === 'ios').tests[0].name, 'native case');
});

test('missing completion and native failures cannot appear successful', async t => {
  const {root, output, native} = await fixture(t);
  await rm(path.join(output, 'completed'));
  assert.equal((await buildReport(root, output)).successful, false);
  await writeFile(path.join(output, 'completed'), 'complete');
  const result = JSON.parse(await readFile(path.join(native, 'results.json'), 'utf8'));
  result.tests['native case'] = 'failure';
  await writeFile(path.join(native, 'results.json'), JSON.stringify(result));
  assert.equal((await buildReport(root, output, [native])).successful, false);
});

test('stale source snapshots cannot be merged with current code', async t => {
  const {root, output, native} = await fixture(t);
  await writeFile(path.join(root, 'lib/main.dart'), 'void main() { print(1); }\n');
  await assert.rejects(buildReport(root, output, [native]), /Sources changed/);
  await writeFile(path.join(output, 'sources.json'), JSON.stringify(await sourceSnapshot(root)));
  await assert.rejects(buildReport(root, output, [native]), /Sources changed/);
});
