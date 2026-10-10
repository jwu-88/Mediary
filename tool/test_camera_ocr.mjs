#!/usr/bin/env node
// Real Chromium video/canvas capture + shipped OCR bridge + Dart detector.
// The only image source substitute is canvas.captureStream(), not OCR output.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile, writeFile, mkdir, stat } from 'node:fs/promises';
import { createServer } from 'node:http';
import { dirname, extname, isAbsolute, resolve, sep } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const options = {};
for (let index = 2; index < process.argv.length; index++) {
  const option = process.argv[index];
  if (option === '--controls' || option === '--require-all-identified') {
    options[option.slice(2)] = true;
  } else if (option.startsWith('--') && process.argv[index + 1]) {
    options[option.slice(2)] = process.argv[++index];
  } else {
    throw new Error(`Unknown option: ${option}`);
  }
}
if (!options.manifest || !options.output) {
  throw new Error('Usage: node tool/test_camera_ocr.mjs --manifest fixtures.json --output results-dir [--build-dir build/web] [--playwright /path/to/playwright/index.mjs] [--chrome /path/to/Chrome] [--bridge-html baseline.html] [--controls] [--require-all-identified]');
}
const repo = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const buildDir = resolve(options['build-dir'] || resolve(repo, 'build/web'));
const outputDir = resolve(options.output);
const manifestPath = resolve(options.manifest);
const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
const fixtures = Array.isArray(manifest) ? manifest : manifest.fixtures;
assert.ok(Array.isArray(fixtures) && fixtures.length >= 5,
  'A camera OCR validation run requires at least five image fixtures.');
await mkdir(outputDir, { recursive: true });
await stat(resolve(buildDir, 'main.dart.js'));

const { chromium } = options.playwright
  ? await import(pathToFileURL(resolve(options.playwright)).href)
  : await import('playwright');
const fixtureFiles = fixtures.map((fixture, index) => {
  const path = fixture.path || fixture.file || fixture.image;
  assert.equal(typeof path, 'string', `Fixture ${index} needs a path.`);
  return isAbsolute(path) ? path : resolve(dirname(manifestPath), path);
});
let baselineBridge;
if (options['bridge-html']) {
  const html = await readFile(resolve(options['bridge-html']), 'utf8');
  baselineBridge = html.match(/<script>\s*(window\.MediaryOcr[\s\S]*?)<\/script>/)?.[1];
  assert.ok(baselineBridge, 'Baseline HTML must contain the inline MediaryOcr bridge.');
}
const mimeTypes = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.json': 'application/json', '.png': 'image/png', '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg', '.wasm': 'application/wasm', '.svg': 'image/svg+xml',
};
const server = createServer(async (request, response) => {
  const url = new URL(request.url, 'http://localhost');
  const match = url.pathname.match(/^\/__fixture\/(\d+)$/);
  const relativePath = url.pathname === '/' ? 'index.html' : decodeURIComponent(url.pathname.slice(1));
  const path = match ? fixtureFiles[Number(match[1])] : resolve(buildDir, relativePath);
  if (!path || (!match && path !== buildDir && !path.startsWith(`${buildDir}${sep}`))) {
    response.writeHead(404).end('Not found');
    return;
  }
  try {
    const bytes = await readFile(path);
    response.writeHead(200, {
      'Content-Type': mimeTypes[extname(path)] || 'application/octet-stream',
      'Cache-Control': 'no-store',
    }).end(bytes);
  } catch {
    response.writeHead(404).end('Fixture or build file unavailable');
  }
});
await new Promise(resolveListen => server.listen(0, '127.0.0.1', resolveListen));
const baseUrl = `http://127.0.0.1:${server.address().port}`;
const browser = await chromium.launch({
  executablePath: options.chrome || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  headless: true,
  args: ['--autoplay-policy=no-user-gesture-required'],
});
const records = [];
const controlRecords = [];
const browserMessages = [];

async function createProbePage(mode = 'fixture') {
  const page = await browser.newPage({ viewport: { width: 1200, height: 900 } });
  const messages = [];
  page.on('pageerror', error => messages.push({ type: 'pageerror', text: error.message }));
  page.on('console', message => {
    if (message.type() === 'warning' || message.type() === 'error') {
      messages.push({ type: message.type(), text: message.text().slice(0, 1000) });
    }
  });
  await page.addInitScript(({ mode }) => {
    const canvas = document.createElement('canvas');
    window.__cameraHarnessCanvas = canvas;
    const context = canvas.getContext('2d');
    let stream;
    let sourceImage;
    window.__cameraHarness = { mode, constraints: [], image: null, captureSource: 'canvas.captureStream' };
    window.__loadCameraFixture = async url => {
      const image = new Image();
      image.src = url;
      await image.decode();
      sourceImage = image;
      canvas.width = image.naturalWidth;
      canvas.height = image.naturalHeight;
      context.drawImage(image, 0, 0);
      window.__cameraHarness.image = { url, width: canvas.width, height: canvas.height };
      await new Promise(resolveFrame => requestAnimationFrame(() => requestAnimationFrame(resolveFrame)));
      // Allow the browser's Video element to present the new camera frame.
      await new Promise(resolveFrame => setTimeout(resolveFrame, 250));
      return window.__cameraHarness.image;
    };
    Object.defineProperty(navigator.mediaDevices, 'getUserMedia', {
      configurable: true,
      value: async constraints => {
        window.__cameraHarness.constraints.push(constraints);
        if (mode === 'denied') throw new DOMException('Camera denied by validation control', 'NotAllowedError');
        if (mode === 'empty-stream') return new MediaStream();
        if (mode === 'missing-fixture') await window.__loadCameraFixture('/__fixture/999999');
        if (!sourceImage) await window.__loadCameraFixture('/__fixture/0');
        stream ||= canvas.captureStream(10);
        return stream;
      },
    });
    function paint() {
      if (sourceImage) context.drawImage(sourceImage, 0, 0);
      requestAnimationFrame(paint);
    }
    requestAnimationFrame(paint);
  }, { mode });
  await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await page.waitForFunction(() => window.MediaryCameraProbeReady && window.MediaryOcr, null, { timeout: 60000 });
  if (baselineBridge) {
    await page.evaluate(bridge => {
      (0, eval)(bridge);
      // The compiled Dart parser stays current; its evidence adapter must
      // receive only the old bridge's text, with no current recovery logic.
      window.MediaryOcr.recognizeWithEvidence = async imageDataUrl => JSON.stringify({
        text: await window.MediaryOcr.recognize(imageDataUrl),
        recoveredUncertainText: false,
      });
    }, baselineBridge);
  }
  await page.evaluate(() => {
    window.__ocrAttempts = [];
    window.__ocrEvidence = null;
    if (typeof window.MediaryOcr.recognizeWithEvidence === 'function') {
      const recognizeWithEvidence = window.MediaryOcr.recognizeWithEvidence;
      window.MediaryOcr.recognizeWithEvidence = async (...arguments_) => {
        const encoded = await recognizeWithEvidence.apply(window.MediaryOcr, arguments_);
        try { window.__ocrEvidence = JSON.parse(encoded); } catch { window.__ocrEvidence = null; }
        return encoded;
      };
    }
    if (!window.Tesseract) return;
    const create = window.Tesseract.createWorker;
    window.Tesseract.createWorker = async (...arguments_) => {
      const worker = await create(...arguments_);
      const recognize = worker.recognize;
      const parameters = worker.setParameters;
      let pageSegmentationMode;
      worker.setParameters = async (...arguments_) => {
        pageSegmentationMode = arguments_[0]?.tessedit_pageseg_mode ?? pageSegmentationMode;
        return parameters.apply(worker, arguments_);
      };
      worker.recognize = async (...arguments_) => {
        const start = performance.now();
        const result = await recognize.apply(worker, arguments_);
        window.__ocrAttempts.push({
          pageSegmentationMode, elapsedMilliseconds: performance.now() - start,
          text: result.data.text, confidence: result.data.confidence,
          lines: result.data.lines?.map(({ text, confidence }) => ({ text, confidence })),
        });
        return result;
      };
      return worker;
    };
  });
  browserMessages.push({ mode, messages });
  return { page, messages };
}

async function probe(page) {
  await page.evaluate(() => { window.__ocrAttempts = []; window.__ocrEvidence = null; });
  const result = await page.evaluate(async () => JSON.parse(await window.MediaryCameraProbe()));
  result.engineAttempts = await page.evaluate(() => window.__ocrAttempts);
  result.ocrEvidence = await page.evaluate(() => window.__ocrEvidence);
  if (!result.captureError) {
    assert.deepEqual(result.pngSignature, [137, 80, 78, 71, 13, 10, 26, 10]);
    assert.ok(result.capturedBytes > 100);
    const camera = await page.evaluate(() => window.__cameraHarness);
    assert.equal(result.frameWidth, camera.image.width, 'Camera capture must preserve the incoming frame width.');
    assert.equal(result.frameHeight, camera.image.height, 'Camera capture must preserve the incoming frame height.');
    result.camera = camera;
    result.pixelComparison = await page.evaluate(async pngDataUrl => {
      const captured = new Image();
      captured.src = pngDataUrl;
      await captured.decode();
      const pixels = image => {
        const canvas = document.createElement('canvas');
        canvas.width = canvas.height = 32;
        const context = canvas.getContext('2d');
        context.fillStyle = 'black';
        context.fillRect(0, 0, 32, 32);
        context.drawImage(image, 0, 0, 32, 32);
        return context.getImageData(0, 0, 32, 32).data;
      };
      const expected = pixels(window.__cameraHarnessCanvas);
      const actual = pixels(captured);
      let totalDifference = 0;
      for (let index = 0; index < actual.length; index++) {
        if (index % 4 !== 3) totalDifference += Math.abs(actual[index] - expected[index]);
      }
      return { sampleWidth: 32, sampleHeight: 32, meanAbsoluteRgbError: totalDifference / (32 * 32 * 3) };
    }, result.pngDataUrl);
    assert.ok(result.pixelComparison.meanAbsoluteRgbError < 10,
      'Captured video must show the current fixture, allowing minor browser video color conversion.');
    if (result.ocrEvidence) {
      assert.equal(result.extractedText, result.ocrEvidence.text.trim(),
        'The detector must preserve raw OCR evidence instead of rewriting the label text.');
      if (result.ocrEvidence.recoveredUncertainText) {
        assert.ok(result.confidence <= 0.65,
          'Medication recognition from recovered uncertain text must retain its confidence cap.');
      }
    }
  }
  return result;
}

function matchesExpected(detected, expected) {
  if (!expected) return null;
  const names = Array.isArray(expected) ? expected : [expected];
  return names.some(name => detected.trim().toLowerCase() === name.trim().toLowerCase());
}

try {
  const { page, messages } = await createProbePage();
  for (const [index, fixture] of fixtures.entries()) {
    const id = String(fixture.id || `fixture-${index + 1}`).replace(/[^a-z0-9_-]/gi, '-');
    try {
      const inputBytes = await readFile(fixtureFiles[index]);
      const image = await page.evaluate(url => window.__loadCameraFixture(url), `/__fixture/${index}`);
      const result = await probe(page);
      assert.equal(result.captureError, '', `Fixture ${id} must reach actual camera frame capture.`);
      assert.ok(result.engineAttempts.length, `Fixture ${id} must reach the real OCR engine; check worker/CDN availability.`);
      const png = Buffer.from(result.pngDataUrl.split(',')[1], 'base64');
      await writeFile(resolve(outputDir, `${id}-captured.png`), png);
      delete result.pngDataUrl;
      const expected = fixture.expectedMedicationName || fixture.expectedName || fixture.expected;
      const identifiedCorrectly = matchesExpected(result.detectedMedicationName, fixture.acceptedMedicationNames || expected);
      records.push({
        id, fixture: { ...fixture, path: fixtureFiles[index] }, image,
        inputSha256: createHash('sha256').update(inputBytes).digest('hex'),
        expectedMedicationName: expected || null,
        identifiedCorrectly,
        expectedManualReview: Boolean(fixture.expectedManualReview),
        behavedAsExpected: fixture.expectedManualReview
          ? result.detectedMedicationName === '' && result.hasError
          : identifiedCorrectly,
        outcome: identifiedCorrectly ? 'identified' : result.detectedMedicationName ? 'different-name' : 'manual-review',
        ...result,
      });
      console.log(`${id}: ${result.detectedMedicationName || 'manual review'} (${result.ocrMilliseconds} ms)`);
      await page.screenshot({ path: resolve(outputDir, `${id}-preview.png`) });
    } catch (error) {
      records.push({ id, fixture, outcome: 'harness-failure', error: error.stack });
      console.error(`${id}: harness failure: ${error.message}`);
    }
    await writeFile(resolve(outputDir, 'results.json'), JSON.stringify({
      generatedAt: new Date().toISOString(), cameraType: 'synthetic canvas video stream',
      baselineBridge: options['bridge-html'] || null, parserHeldConstant: Boolean(baselineBridge),
      records, controls: controlRecords, browserMessages,
    }, null, 2));
  }
  await page.close();

  if (options.controls) {
    for (const mode of ['denied', 'empty-stream', 'missing-fixture']) {
      const { page: control } = await createProbePage(mode);
      try {
        const result = await probe(control);
        assert.equal(result.captureError, mode === 'empty-stream' ? 'frame-unavailable' : 'camera-unavailable');
        controlRecords.push({ id: mode, passed: true, ...result });
        console.log(`control ${mode}: passed`);
      } finally { await control.close(); }
    }
    const { page: control } = await createProbePage();
    try {
      await control.evaluate(() => {
        const create = window.Tesseract.createWorker;
        window.Tesseract.createWorker = async (...arguments_) => {
          window.Tesseract.createWorker = create;
          throw new Error('Induced worker initialization failure for validation');
        };
      });
      const failed = await probe(control);
      assert.equal(failed.detectedMedicationName, '');
      assert.equal(failed.hasError, true);
      const recovered = await probe(control);
      assert.ok(recovered.engineAttempts.length, 'The next scan must retry the real OCR engine.');
      delete failed.pngDataUrl;
      delete recovered.pngDataUrl;
      controlRecords.push({ id: 'worker-initialization-failure-and-recovery', passed: true, failed, recovered });
      console.log('control worker-initialization-failure-and-recovery: passed');
    } finally { await control.close(); }
  }
} finally {
  const summary = {
    count: records.length,
    identifiedCorrectly: records.filter(record => record.identifiedCorrectly === true).length,
    manualReview: records.filter(record => record.outcome === 'manual-review').length,
    differentName: records.filter(record => record.outcome === 'different-name').length,
    harnessFailures: records.filter(record => record.outcome === 'harness-failure').length,
    controlsPassed: controlRecords.filter(record => record.passed).length,
    expectedManualReviewsPassed: records.filter(record => record.expectedManualReview && record.behavedAsExpected).length,
  };
  await writeFile(resolve(outputDir, 'results.json'), JSON.stringify({
    generatedAt: new Date().toISOString(), cameraType: 'synthetic canvas video stream',
    baselineBridge: options['bridge-html'] || null, parserHeldConstant: Boolean(baselineBridge),
    summary, records, controls: controlRecords, browserMessages,
  }, null, 2));
  console.log(JSON.stringify(summary));
  await browser.close();
  await new Promise(resolveClose => server.close(resolveClose));
  if (summary.harnessFailures || summary.differentName || (options['require-all-identified'] && summary.identifiedCorrectly !== summary.count)) {
    process.exitCode = 1;
  }
}
