import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));
const read = (name) => existsSync(join(root, name)) ? readFileSync(join(root, name), 'utf8') : '';
const html = read('ui-proto.html');
const css = read('styles.css');
const js = read('app.js');

const includes = (source, fragment, message) =>
  assert.ok(source.includes(fragment), `${message}: missing ${fragment}`);

// Semantic screen contract.
for (const screen of ['audio', 'profile', 'settings']) {
  includes(html, `data-screen="${screen}"`, `screen ${screen}`);
}
for (const layer of ['paper', 'bridge', 'mountains', 'water']) {
  includes(html, `data-stage-layer="${layer}"`, `stage layer ${layer}`);
}
assert.equal((html.match(/data-pipeline-id=/g) ?? []).length, 4, 'exactly four pipeline cards');
includes(html, 'id="streamButton"', 'stream button');
includes(html, 'id="bottomNav"', 'bottom navigation');
includes(html, 'id="confirmDialog"', 'destructive action dialog');
includes(html, 'id="audioSettingDialog"', 'streaming audio-setting dialog');
includes(html, 'id="developerGroup"', 'developer settings group');

// Design-system contract.
for (const token of ['--surface:', '--on-surface:', '--primary:', '--error:', '--outline-variant:']) {
  includes(css, token, `semantic color token ${token}`);
}
includes(css, '[data-theme="dark"]', 'dark color scheme');
includes(css, '--radius-card: 12px', 'card radius');
includes(css, '--radius-dialog: 28px', 'dialog radius');
includes(css, 'min-height: 48px', 'minimum interactive target');
includes(css, '@media (max-height: 640px)', 'compact height mode');
includes(css, '@media (prefers-reduced-motion: reduce)', 'reduced motion support');
includes(css, 'grid-template-columns: repeat(2, minmax(0, 1fr))', '2 by 2 pipeline grid');
includes(css, 'max(32px, env(safe-area-inset-bottom))', 'stream button safe-area clearance');
includes(css, '@keyframes mountain-land', 'connecting mountain overshoot');
includes(css, '--selection-fill: 8%', 'light selected-card fill');
includes(css, '--selection-fill: 12%', 'dark selected-card fill');

// Interaction/state contract.
for (const state of ['IDLE', 'PERMISSION_REQUESTING', 'CONNECTING', 'STREAMING', 'ERROR']) {
  includes(js, state, `stream state ${state}`);
}
for (const api of ['setStreamState', 'selectPipeline', 'beginStopHold', 'cancelStopHold', 'navigate', 'registerVersionTap', 'openConfirmDialog', 'applyAudioSetting']) {
  includes(js, `function ${api}`, `interaction ${api}`);
}
includes(js, '800', '800ms hold threshold');
includes(js, 'versionTapCount === 5', 'five-tap developer activation');
includes(js, 'function hydratePreviewState', 'deterministic browser QA state');
includes(js, 'URLSearchParams', 'browser QA query state');
includes(js, 'matchMedia', 'system theme following');
includes(js, 'visibilitychange', 'background animation freeze');
includes(js, "navigator.vibrate?.(10)", 'press haptic feedback');
assert.ok(!html.includes('profile-hero'), 'profile page must not invent an unspecified hero');

console.log('Prototype contract passed.');
