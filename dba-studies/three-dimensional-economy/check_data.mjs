import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const sandbox = { window: {} };
runInNewContext(readFileSync(new URL('./data.js', import.meta.url), 'utf8'), sandbox);
const quarters = sandbox.window.BEFOREIT_TRACE.quarters;
assert.equal(quarters.length, 31);
assert.deepEqual(Array.from(quarters, q => q.quarter), Array.from({ length: 31 }, (_, i) => i));
assert.equal(quarters[0].firms.length, 624);
for (const quarter of quarters) {
  const ids = quarter.firms.map(row => row[0]);
  assert.equal(new Set(ids).size, ids.length);
  assert.ok(Number.isFinite(quarter.gdp) && Number.isFinite(quarter.unemployment));
  assert.ok(quarter.firms.every(row => row.length === 10 && row.every(Number.isFinite)));
}
console.log('31 quarters and firm records validated');
