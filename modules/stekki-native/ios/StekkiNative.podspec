Pod::Spec.new do |s|
  s.name = 'StekkiNative'
  s.module_name = 'Stekki'
  s.version = '1.0.0'
  s.summary = 'Stekki on-device editor and persistence for Expo'
  s.description = 'Reuses the existing SwiftUI editor, SwiftData schema, Vision and stickertrade implementation.'
  s.author = 'Hamaryo226'
  s.homepage = 'https://github.com/Hamaryo226/Stekki'
  s.license = { :type => 'UNLICENSED' }
  s.source = { :git => 'https://github.com/Hamaryo226/Stekki.git' }
  s.platforms = { :ios => '17.0' }
  s.swift_version = '5.0'
  s.static_framework = true
  s.dependency 'ExpoModulesCore'
  s.source_files = '**/*.swift'
  s.frameworks = 'SwiftUI', 'SwiftData', 'Vision', 'PhotosUI', 'CryptoKit'
  s.libraries = 'z'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
