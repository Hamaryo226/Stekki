import type { ExpoConfig } from 'expo/config';

const config: ExpoConfig = {
  name: 'Stekki',
  slug: 'stekki',
  version: '1.0.0',
  scheme: 'stekki',
  platforms: ['ios'],
  userInterfaceStyle: 'automatic',
  ios: { bundleIdentifier: 'hamaryo.Stekki', supportsTablet: true },
  plugins: [
    ['expo-image-picker', { photosPermission: 'シールにする写真を選びます。', cameraPermission: false, microphonePermission: false }],
  ],
};
export default config;
