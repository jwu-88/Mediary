import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

// Exercise the shipped bridge, not a duplicate implementation. Image decode
// failure routes directly to the engine and makes worker lifecycle deterministic.
const html = readFileSync(new URL('../web/index.html', import.meta.url), 'utf8');
const bridge = html.match(/<script>\s*(window\.MediaryOcr[\s\S]*?)<\/script>/)[1];

function harness({ failFirst = false, decode = false, width = 800, height = 715, results } = {}) {
  const calls = [];
  const canvases = [];
  let workers = 0;
  let busy = false;
  const Tesseract = {
    async createWorker(...args) {
      assert.equal(args.length, 1, 'v4 accepts only an options object');
      assert.equal(typeof args[0], 'object');
      assert.match(args[0].workerPath, /4\.1\.1/);
      const id = ++workers;
      let ready = false;
      return {
        async loadLanguage(lang) { calls.push(`load:${lang}`); },
        async initialize(lang) { ready = true; calls.push(`init:${lang}`); },
        async setParameters() { assert.ok(ready, 'language must initialize first'); },
        async recognize() {
          assert.equal(busy, false, 'shared worker must not overlap scans');
          busy = true;
          await new Promise(resolve => setTimeout(resolve, 2));
          busy = false;
          if (failFirst && id === 1) throw new Error('temporary worker failure');
          calls.push('recognize');
          const texts = ['loratadine 10 mg', 'Claritin-D', 'CLARITIN-D', 'pseudoephedrine 240 mg'];
          const index = calls.filter(x => x === 'recognize').length - 1;
          return { data: results ? results[index % results.length] : { text: texts[index % 4] } };
        },
        async terminate() { calls.push('terminate'); },
      };
    },
  };
  function canvas() {
    const result = {
      width: 0, height: 0,
      toDataURL() { return 'data:image/png;base64,test'; },
      getContext() {
        return {
          fillRect() {}, drawImage() {},
          putImageData(pixels) { result.pixels = Array.from(pixels.data); },
          translate() {}, rotate() {},
          getImageData() { return { data: new Uint8ClampedArray([128, 128, 128, 255]) }; },
          createImageData() { return { data: new Uint8ClampedArray([128, 128, 128, 255]) }; },
        };
      },
    };
    canvases.push(result);
    return result;
  }
  const context = vm.createContext({
    window: { Tesseract }, Tesseract,
    console: { warn() {} }, Uint32Array, Map,
    document: { createElement: canvas },
    Image: class {
      naturalWidth = width;
      naturalHeight = height;
      set src(_) { queueMicrotask(() => decode ? this.onload() : this.onerror()); }
    },
  });
  vm.runInContext(bridge, context);
  return { ocr: context.window.MediaryOcr, calls, canvases, get workers() { return workers; } };
}

test('v4 worker initializes English and is reused across queued scans', async () => {
  const h = harness();
  await Promise.all([h.ocr.recognize('photo1'), h.ocr.recognize('photo2')]);
  assert.deepEqual(h.calls, ['load:eng', 'init:eng', 'recognize', 'recognize']);
  assert.equal(h.workers, 1);
});

test('failed worker is terminated and the next scan recovers', async () => {
  const h = harness({ failFirst: true });
  assert.equal(await h.ocr.recognize('bad'), '');
  assert.ok(await h.ocr.recognize('retry'));
  assert.equal(h.workers, 2);
  assert.ok(h.calls.includes('terminate'));
});

test('all image passes contribute text without case-insensitive duplicates', async () => {
  const h = harness({ decode: true });
  assert.equal(await h.ocr.recognize('photo'), 'loratadine 10 mg\nClaritin-D\npseudoephedrine 240 mg');
  assert.equal(h.canvases[0].width, 2000);
});

test('large uploads are downscaled to the OCR memory bound', async () => {
  const h = harness({ decode: true, width: 6000, height: 4000 });
  await h.ocr.recognize('large');
  assert.equal(h.canvases[0].width, 2400);
  assert.equal(h.canvases[0].height, 1600);
});

test('camera noise is discarded while whole readable label lines survive', async () => {
  const h = harness({ decode: true, results: [{
    lines: [
      { text: '_— M——', confidence: 80 },
      { text: 'anhcnhydmmme HCl 25 mg', confidence: 22 },
      { text: 'Benadryl', confidence: 92 },
      { text: 'Diphenhydramine  HCl 25 mg', confidence: 87 },
      { text: 'Do not take with loratadine', confidence: 88 },
    ],
  }] });
  assert.equal(await h.ocr.recognize('camera'),
    'Benadryl\nDiphenhydramine HCl 25 mg\nDo not take with loratadine');
});

test('unreadable camera output returns empty text for retake guidance', async () => {
  const h = harness({ decode: true, results: [{ text: 'M---\n&\nQzxv random', confidence: 20 }] });
  assert.equal(await h.ocr.recognize('camera'), '');
});

test('light-on-dark text gets an inverted grayscale recognition pass', async () => {
  const h = harness({ decode: true });
  await h.ocr.recognize('camera');
  assert.ok(h.canvases.some(canvas => canvas.pixels?.[0] === 127 && canvas.pixels?.[3] === 255));
});
