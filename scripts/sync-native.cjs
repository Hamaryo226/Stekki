// Keep one authoritative Swift source tree for both the original app and Expo.
const { cpSync, mkdirSync, rmSync } = require('node:fs');
const { resolve } = require('node:path');
const root = resolve(__dirname, '..');
const target = resolve(root, 'modules/stekki-native/ios/Core');
rmSync(target, { recursive: true, force: true });
mkdirSync(target, { recursive: true });
for (const folder of ['Models', 'Persistence', 'DesignSystem', 'Features']) {
  cpSync(resolve(root, 'Stekki', folder), resolve(target, folder), { recursive: true });
}
// StekkiApp.swift is intentionally excluded: Expo owns the application entry point.
