import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const directory = new URL('.', import.meta.url);
const html = readFileSync(new URL('market.html', directory), 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
assert.ok(script, 'market page must have an inline script');

class Element {
  constructor() { this.children = []; this.listeners = {}; this.value = ''; this.style = {}; this.textContent = ''; }
  append(child) { this.children.push(child); }
  replaceChildren() { this.children = []; }
  addEventListener(name, listener) { this.listeners[name] = listener; }
  fire(name) { assert.ok(this.listeners[name]); this.listeners[name](); }
}
const elements = new Map();
const document = {
  getElementById(id) { if (!elements.has(id)) elements.set(id, new Element()); return elements.get(id); },
  createElement() { return new Element(); }
};
const get = id => document.getElementById(id);
get('quarter').value = '1';
const sandbox = { window: {}, document, Intl, Math };
runInNewContext(readFileSync(new URL('data.js', directory), 'utf8'), sandbox);
runInNewContext(script, sandbox);

assert.match(get('sector-title').textContent, /^Sector \d+/);
assert.ok(get('seller-list').children.length > 0);
const startingBudget = Number(get('budget').value);
assert.ok(startingBudget > 0);
get('next').fire('click');
assert.ok(Number(get('spent').textContent.replaceAll(',', '')) > 0);
assert.ok(Number(get('budget-left').textContent.replaceAll(',', '')) < startingBudget);
assert.match(get('event').textContent, /matched/);
get('budget').value = '1000000000';
get('budget').fire('change');
const sellerCount = get('seller-list').children.length;
let matches = 0;
while (!get('next').disabled && matches <= sellerCount) { get('next').fire('click'); matches++; }
assert.equal(matches, sellerCount, 'each exhausted seller leaves the draw pool');
assert.equal(get('next').disabled, true);
get('reset').fire('click');
assert.equal(get('spent').textContent, '0');
get('quarter').value = '2';
get('quarter').fire('input');
assert.equal(get('quarter-label').textContent, 'Q2');
get('sector').value = '5';
get('sector').fire('change');
assert.match(get('sector-title').textContent, /^Sector 5 ·/);
get('dataset').value = '1';
get('dataset').fire('change');
assert.ok(get('seller-list').children.length > 0);
console.log('Market selectors and example buyer validated');
