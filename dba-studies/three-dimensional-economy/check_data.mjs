import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const sandbox = { window: {} };
runInNewContext(readFileSync(new URL('./data.js', import.meta.url), 'utf8'), sandbox);
const { quarters, sectors } = sandbox.window.BEFOREIT_TRACE;
const cheatsheet = readFileSync(new URL('../model-mechanics/sector-cheatsheet.md', import.meta.url), 'utf8')
  .split('## Complete mapping')[1].split('## Interpretation notes')[0];
const mapped = [...cheatsheet.matchAll(/^\|\s*(\d+)\s*\|\s*([^|]+)\s*\|\s*([^|]+)\s*\|/gm)]
  .map(([, id, nace, description]) => [Number(id), nace.trim(), description.trim()]);
assert.equal(mapped.length, 62);
for (const [id, nace, description] of mapped) {
  assert.deepEqual(Array.from(sectors[id]), [nace, description]);
}
assert.equal(quarters.length, 31);
assert.deepEqual(Array.from(quarters, q => q.quarter), Array.from({ length: 31 }, (_, i) => i));
assert.equal(quarters[0].firms.length, 624);
for (const quarter of quarters) {
  const ids = quarter.firms.map(row => row[0]);
  assert.equal(new Set(ids).size, ids.length);
  assert.ok(Number.isFinite(quarter.gdp) && Number.isFinite(quarter.unemployment));
  assert.ok(quarter.firms.every(row => row.length === 10 && row.every(Number.isFinite)));
  assert.ok(quarter.firms.every(row => sectors[row[1]]));
}
console.log('31 quarters, firm records, and 62 sector descriptions validated');
