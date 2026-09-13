import {readFile, readdir, writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';

// Union hits across package tests and root flows, not a mean of percentages.
export function mergeLcov(text, {directory, packages}, records = new Map()) {
  let record;
  for (const line of text.split(/\r?\n/)) {
    if (line.startsWith('SF:')) {
      let source = line.slice(3);
      if (source.startsWith('package:')) {
        const [name, ...parts] = source.slice(8).split('/');
        const root = packages.get(name);
        if (!root) throw new Error(`Unknown package in LCOV: ${name}`);
        source = path.join(root, 'lib', ...parts);
      } else if (source.startsWith('file:')) {
        source = fileURLToPath(source);
      } else {
        source = path.resolve(directory, source);
      }
      record = records.get(source) ?? {lines: new Map(), branches: new Map()};
      records.set(source, record);
    } else if (line === 'end_of_record') {
      record = undefined;
    } else if (line.startsWith('DA:') || line.startsWith('BRDA:')) {
      if (!record) throw new Error('Coverage entry without source file');
      const values = line.slice(line.indexOf(':') + 1).split(',');
      const branch = line.startsWith('BRDA:');
      const key = branch ? values.slice(0, 3).join(',') : Number(values[0]);
      const rawHits = values[branch ? 3 : 1];
      const hits = rawHits === '-' ? 0 : Number(rawHits);
      if (!Number.isFinite(hits) || hits < 0) throw new Error(`Invalid hits: ${line}`);
      const target = branch ? record.branches : record.lines;
      target.set(key, Math.max(target.get(key) ?? 0, hits));
    }
  }
  return records;
}

export function parseTestEvents(text) {
  const suites = new Map();
  const tests = new Map();
  let success;
  for (const line of text.trim().split(/\r?\n/).filter(Boolean)) {
    const event = JSON.parse(line);
    if (event.type === 'suite') suites.set(event.suite.id, event.suite.path);
    if (event.type === 'testStart') tests.set(event.test.id, {...event.test});
    if (event.type === 'testDone') {
      const test = tests.get(event.testID);
      if (!test) throw new Error('Test completed without testStart');
      Object.assign(test, {
        result: event.result,
        skipped: event.skipped,
        hidden: event.hidden,
      });
    }
    if (event.type === 'done') success = event.success;
  }
  if (typeof success !== 'boolean') throw new Error('Incomplete test run: missing done');
  if ([...tests.values()].some(test => test.result == null)) {
    throw new Error('Incomplete test run: missing testDone');
  }
  return {
    success,
    tests: [...tests.values()].filter(test => !test.hidden).map(test => ({
      name: test.name,
      file: suites.get(test.suiteID),
      status: test.skipped ? 'skipped' : test.result ?? 'incomplete',
    })),
  };
}

export function summarize(record) {
  const lines = [...(record?.lines ?? [])];
  const branches = [...(record?.branches ?? [])];
  return {
    measured: record != null && lines.length > 0,
    linesHit: lines.filter(([, hits]) => hits > 0).length,
    linesFound: lines.length,
    branchesHit: branches.filter(([, hits]) => hits > 0).length,
    branchesFound: branches.length,
    uncoveredLines: lines.filter(([, hits]) => hits === 0).map(([line]) => line),
    uncoveredBranches: branches.filter(([, hits]) => hits === 0).map(([key]) => key),
  };
}

async function dartSources(directory) {
  const files = [];
  for (const entry of await readdir(directory, {withFileTypes: true})) {
    const file = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...await dartSources(file));
    else if (file.endsWith('.dart')) files.push(file);
  }
  return files;
}

async function packagePaths(root) {
  const configPath = path.join(root, '.dart_tool/package_config.json');
  const config = JSON.parse(await readFile(configPath, 'utf8'));
  return new Map(config.packages.map(pkg => [
    pkg.name, path.resolve(fileURLToPath(new URL(pkg.rootUri, pathToFileURL(configPath)))),
  ]));
}

function owned(root, packages) {
  return [...packages].filter(([, dir]) => dir === root ||
    dir.startsWith(path.join(root, 'packages') + path.sep));
}

export async function sourceSnapshot(root) {
  const packages = owned(root, await packagePaths(root));
  const files = [];
  for (const [, directory] of packages) {
    files.push(...await dartSources(path.join(directory, 'lib')));
    try {
      files.push(...await dartSources(path.join(directory, 'test')));
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
    files.push(path.join(directory, 'pubspec.yaml'));
  }
  for (const directory of ['integration_test', 'test_driver']) {
    try {
      files.push(...await dartSources(path.join(root, directory)));
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
  }
  for (const file of ['pubspec.lock', '.fvmrc']) {
    try {
      await readFile(path.join(root, file));
      files.push(path.join(root, file));
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
  }
  const hashes = {};
  for (const file of [...new Set(files)].sort()) {
    hashes[path.relative(root, file)] = createHash('sha256')
      .update(await readFile(file)).digest('hex');
  }
  return {packages: packages.map(([name]) => name).sort(), files: hashes};
}

async function verifySnapshot(directory, current) {
  const previous = JSON.parse(await readFile(path.join(directory, 'sources.json'), 'utf8'));
  if (JSON.stringify(previous) !== JSON.stringify(current)) {
    throw new Error(`Sources changed since ${directory}; rerun tests before merging coverage`);
  }
}

export async function buildReport(root, output, nativeDirectories = []) {
  const packages = await packagePaths(root);
  const ownedPackages = owned(root, packages);
  const snapshot = await sourceSnapshot(root);
  await verifySnapshot(output, snapshot);
  const manifest = (await readFile(path.join(output, 'suites.tsv'), 'utf8')).trim();
  if (!manifest) throw new Error('Empty coverage run');
  const complete = await readFile(path.join(output, 'completed'), 'utf8')
    .then(value => value.trim() === 'complete', () => false);
  const records = new Map();
  const suites = [];
  for (const row of manifest.split('\n')) {
    const [name, directory, status, measured] = row.split('\t');
    const suite = {name, exitCode: Number(status), dartCoverage: measured === 'true'};
    if (suite.dartCoverage) {
      mergeLcov(await readFile(path.join(output, name, 'lcov.info'), 'utf8'), {
        directory, packages,
      }, records);
      Object.assign(suite, parseTestEvents(await readFile(
        path.join(output, name, 'tests.jsonl'), 'utf8')));
    }
    suites.push(suite);
  }
  for (const directory of new Set(nativeDirectories)) {
    await verifySnapshot(directory, snapshot);
    const data = JSON.parse(await readFile(path.join(directory, 'results.json'), 'utf8'));
    const tests = Object.entries(data.tests ?? {}).map(([name, status]) => ({name, status}));
    if (!tests.length || !['android', 'ios'].includes(data.platform) ||
        !Number.isFinite(Date.parse(data.completedAt))) {
      throw new Error(`Incomplete native test evidence: ${directory}`);
    }
    const success = tests.every(test => test.status === 'success');
    mergeLcov(await readFile(path.join(directory, 'lcov.info'), 'utf8'), {
      directory: root, packages,
    }, records);
    suites.push({
      name: `native:${path.relative(root, directory)}`, platform: data.platform,
      exitCode: success ? 0 : 1, success, dartCoverage: true, tests,
    });
  }
  const files = [];
  const excludedFiles = [];
  for (const [packageName, directory] of ownedPackages) {
    for (const file of await dartSources(path.join(directory, 'lib'))) {
      const relative = path.relative(root, file);
      if (relative.includes('/generated/') || /\.(g|freezed)\.dart$/.test(file)) {
        excludedFiles.push(relative);
      } else {
        files.push({package: packageName, file: relative, ...summarize(records.get(file))});
      }
    }
  }
  const packageTotals = ownedPackages.map(([name]) => {
    const sources = files.filter(file => file.package === name);
    return {
      name,
      files: sources.length,
      unmeasuredFiles: sources.filter(file => !file.measured).length,
      ...Object.fromEntries(['linesHit', 'linesFound', 'branchesHit', 'branchesFound']
        .map(key => [key, sources.reduce((sum, file) => sum + file[key], 0)])),
    };
  }).sort((a, b) => a.name.localeCompare(b.name));
  return {
    createdAt: new Date().toISOString(),
    complete,
    successful: complete && suites.every(suite => suite.exitCode === 0 && suite.success !== false),
    scope: 'Owned active Dart packages. JS/browser suites are execution evidence, not Dart coverage. Explicitly supplied native runs add line coverage only.',
    limitation: 'Percentages cover VM-reported executable lines only. Unmeasured files (including export-only files) are listed, never treated as covered.',
    excludedFiles, packages: packageTotals, files, suites,
  };
}

function ratio(hit, total) {
  return total === 0 ? 'unmeasured' : `${hit}/${total} (${(100 * hit / total).toFixed(1)}%)`;
}

export function markdownReport(report) {
  const lines = [
    '# Coverage Run', '', report.scope, '', report.limitation, '',
    `Successful: ${report.successful}`, '',
    '| Package | Lines | Branches | Unmeasured files |',
    '| --- | --- | --- | --- |',
    ...report.packages.map(pkg => `| ${pkg.name} | ${ratio(pkg.linesHit, pkg.linesFound)} | ${ratio(pkg.branchesHit, pkg.branchesFound)} | ${pkg.unmeasuredFiles} |`),
    '', '## Largest Measured Gaps', '',
    ...report.files.filter(file => file.uncoveredLines.length > 0)
      .sort((a, b) => b.uncoveredLines.length - a.uncoveredLines.length)
      .slice(0, 40).map(file => `- ${file.file}: ${file.uncoveredLines.length} uncovered lines; ${file.uncoveredBranches.length} uncovered branches.`),
    '', '## Unmeasured Files', '',
    ...report.files.filter(file => !file.measured).map(file => `- ${file.file}`),
    '', 'Full per-line/per-branch gaps, exclusions and test names: report.json.', '',
  ];
  return lines.join('\n');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const snapshotOnly = process.argv[2] === '--snapshot';
  const output = process.argv[snapshotOnly ? 3 : 2];
  if (!output) throw new Error('Usage: node scripts/coverage_report.mjs [--snapshot] <run-directory> [native-run-directories...]');
  const root = fileURLToPath(new URL('../', import.meta.url)).replace(/\/$/, '');
  if (snapshotOnly) {
    await writeFile(path.join(output, 'sources.json'), JSON.stringify(await sourceSnapshot(root)));
  } else {
    const report = await buildReport(root, path.resolve(output), process.argv.slice(3).map(dir => path.resolve(dir)));
    await writeFile(path.join(output, 'report.json'), JSON.stringify(report, null, 2));
    await writeFile(path.join(output, 'report.md'), markdownReport(report));
    console.log(markdownReport(report).split('## Largest')[0]);
    console.log(`Report: ${path.join(output, 'report.md')}`);
    if (!report.successful) process.exitCode = 1;
  }
}
