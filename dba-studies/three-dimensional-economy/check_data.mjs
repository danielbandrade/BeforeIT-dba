import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const sandbox = { window: {} };
runInNewContext(readFileSync(new URL('./data.js', import.meta.url), 'utf8'), sandbox);
const { datasets, sectors } = sandbox.window.BEFOREIT_EXPERIMENTS;
const cheatsheet = readFileSync(new URL('../model-mechanics/sector-cheatsheet.md', import.meta.url), 'utf8')
  .split('## Complete mapping')[1].split('## Interpretation notes')[0];
const mapped = [...cheatsheet.matchAll(/^\|\s*(\d+)\s*\|\s*([^|]+)\s*\|\s*([^|]+)\s*\|/gm)]
  .map(([, id, nace, description]) => [Number(id), nace.trim(), description.trim()]);
assert.equal(mapped.length, 62);
for (const [id, nace, description] of mapped) {
  assert.deepEqual(Array.from(sectors[id]), [nace, description]);
}
assert.ok(datasets.length >= 11);
assert.equal(new Set(datasets.map(item => `${item.experiment}/${item.run}`)).size, datasets.length);
for (const dataset of datasets) {
  assert.equal(dataset.quarters.length, dataset.horizon + 1);
  assert.deepEqual(Array.from(dataset.quarters, q => q.quarter),
    Array.from({ length: dataset.horizon + 1 }, (_, i) => i));
  for (const quarter of dataset.quarters) {
    const ids = quarter.firms.map(row => row[0]);
    assert.equal(new Set(ids).size, ids.length);
    assert.ok(Number.isFinite(quarter.gdp) && Number.isFinite(quarter.unemployment));
    assert.ok(quarter.firms.every(row => row.length === 13 && row.every(Number.isFinite)));
    assert.ok(quarter.firms.every(row => sectors[row[1]]));
    assert.equal(quarter.imports.length, 62);
    assert.ok(quarter.imports.every(row => row.length === 3 && row.every(Number.isFinite)));
    if (quarter.quarter > 0) {
      assert.ok(quarter.firms.every(row => row[10] > 0 && row[11] >= 0 && row[12] >= -1e-8));
      assert.ok(quarter.imports.every(([price, supply, sold]) =>
        price > 0 && supply >= 0 && sold >= 0 && sold <= supply + 1e-8));
    }
  }
}
console.log(`${datasets.length} experiment runs and 62 sector descriptions validated`);
