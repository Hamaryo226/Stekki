const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const { readFileSync, readdirSync, existsSync } = require('node:fs');
const { resolve, join } = require('node:path');
const root = resolve(__dirname, '..');
const core = join(root, 'modules/stekki-native/ios/Core');
function verify(relative) {
  const original = join(root, 'Stekki', relative);
  for (const entry of readdirSync(original, { withFileTypes: true })) {
    const child = join(relative, entry.name);
    if (entry.isDirectory()) verify(child);
    else assert.deepEqual(readFileSync(join(core, child)), readFileSync(join(root, 'Stekki', child)), child);
  }
}
for (const folder of ['Models', 'Persistence', 'DesignSystem', 'Features']) verify(folder);
assert.equal(existsSync(join(core, 'StekkiApp.swift')), false, 'Expo must own @main');
const cli = require.resolve('expo-modules-autolinking/bin/expo-modules-autolinking');
const resolution = JSON.parse(execFileSync(process.execPath, [cli, 'resolve', '--platform', 'apple', '--json'], { cwd: root }));
const moduleInfo = resolution.modules.find(item => item.packageName === 'stekki-native');
assert.ok(moduleInfo, 'Local module must be discovered');
assert.deepEqual(moduleInfo.swiftModuleNames, ['Stekki'], 'Preserve the original Swift module identity');
assert.ok(moduleInfo.modules.some(item => item.class === 'StekkiNativeModule'));
console.log('Native sources and Expo module registration verified.');
