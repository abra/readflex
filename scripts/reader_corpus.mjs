import {createHash} from 'node:crypto';
import {mkdir, readFile, readdir, stat, writeFile} from 'node:fs/promises';
import path from 'node:path';

const [source, output] = process.argv.slice(2);
if (!source || !output || process.argv.length !== 4) {
  throw new Error('Use node scripts/reader_corpus.mjs <book directory> <selection.json>');
}
const formats = new Map();
async function scan(directory) {
  for (const entry of await readdir(directory, {withFileTypes: true})) {
    if (entry.name === 'System' || entry.name.startsWith('.')) continue;
    const file = path.join(directory, entry.name);
    if (entry.isDirectory()) await scan(file);
    else if (entry.isFile()) {
      const format = entry.name.toLowerCase().match(/\.(fb2\.zip|epub|mobi|azw3|fb2|cbz|cbr|pdf|djvu)$/)?.[1];
      if (!format) continue;
      if (!formats.has(format)) formats.set(format, []);
      formats.get(format).push({path: file, bytes: (await stat(file)).size});
    }
  }
}
await scan(path.resolve(source));
const selection = [];
for (const [format, limit] of [['epub', 12], ['mobi', 8], ['azw3', 4],
  ['fb2', 4], ['fb2.zip', 4], ['cbz', 4]]) {
  const candidates = (formats.get(format) ?? []).sort((a, b) =>
    a.bytes - b.bytes || a.path.localeCompare(b.path, 'en'));
  const uniqueSizes = [...new Map(candidates.map(item => [item.bytes, item])).values()];
  const count = Math.min(limit, uniqueSizes.length);
  const indexes = [...Array(count)].map((_, i) =>
    count === 1 ? 0 : Math.round(i * (uniqueSizes.length - 1) / (count - 1)));
  const hashes = new Set();
  let accepted = 0;
  for (const index of [...indexes, ...uniqueSizes.keys()]) {
    if (accepted === count) break;
    const item = uniqueSizes[index];
    const hash = createHash('sha256').update(await readFile(item.path)).digest('hex');
    if (hashes.has(hash)) continue;
    hashes.add(hash);
    accepted++;
    selection.push({...item, format, sha256: hash,
      id: `${format.replace('.', '-')}-${String(accepted).padStart(2, '0')}`});
  }
}
await mkdir(path.dirname(output), {recursive: true});
await writeFile(output, JSON.stringify(selection, null, 2));
process.stdout.write(`${JSON.stringify({
  available: Object.fromEntries([...formats].map(([format, files]) => [format, files.length])),
  selected: Object.fromEntries([...new Set(selection.map(item => item.format))]
    .map(format => [format, selection.filter(item => item.format === format).length])),
  output: path.resolve(output),
}, null, 2)}\n`);
