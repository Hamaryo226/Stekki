import type { ExpoConfig } from 'expo/config';

const config: ExpoConfig = {
  name: 'Stekki Expo',
  slug: 'stekki',
  version: '1.0.0',
  scheme: 'stekki',
  platforms: ['ios'],
  userInterfaceStyle: 'automatic',
  ios: {
    bundleIdentifier: 'hamaryo.Stekki',
    supportsTablet: true,
    infoPlist: {
      CFBundleDisplayName: 'Stekki',
      LSSupportsOpeningDocumentsInPlace: false,
      UTExportedTypeDeclarations: [{
        UTTypeIdentifier: 'jp.hamaryo.stekki.stickertrade',
        UTTypeDescription: 'Stekki Sticker Trade',
        UTTypeConformsTo: ['public.data'],
        UTTypeTagSpecification: {
          'public.filename-extension': ['stickertrade'],
          'public.mime-type': 'application/vnd.stekki.stickertrade+zip',
        },
      }],
      CFBundleDocumentTypes: [{
        CFBundleTypeName: 'Stekki Sticker Trade',
        CFBundleTypeRole: 'Viewer', LSHandlerRank: 'Owner',
        LSItemContentTypes: ['jp.hamaryo.stekki.stickertrade'],
      }],
    },
  },
  plugins: [
    ['expo-build-properties', { ios: { deploymentTarget: '17.0' } }],
  ],
};
export default config;
