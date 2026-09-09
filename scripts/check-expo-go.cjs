const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const pkg = require(path.join(root, 'package.json'));
const bundled = require('expo/bundledNativeModules.json');
const pure = new Set(['expo', 'react', 'react-native', 'fflate']);
for (const name of Object.keys(pkg.dependencies)) {
  assert.ok(pure.has(name) || Object.hasOwn(bundled, name), `${name} is not in the Expo bundled-module catalog`);
}
assert.ok(!pkg.dependencies['expo-dev-client'], 'Expo Go must not depend on a development client');
assert.ok(pkg.scripts.start.includes('--go'));
function scan(folder) {
  if (!fs.existsSync(folder)) return;
  for (const entry of fs.readdirSync(folder, { withFileTypes: true })) {
    const file = path.join(folder, entry.name);
    if (entry.isDirectory()) scan(file);
    else assert.notEqual(entry.name, 'expo-module.config.json', 'No custom module may require a native build');
  }
}
scan(path.join(root, 'modules'));
console.log('Expo Go dependency and native-module guards passed.');
