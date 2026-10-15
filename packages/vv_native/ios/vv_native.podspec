#
# Vends the prebuilt vv_native.xcframework (device + simulator) produced by
# `native/build.sh ios`, which copies it to ios/Frameworks/ (gitignored).
# UNVERIFIED locally (no Xcode on the authoring machine); the CI iOS job is the
# first real build.
#
Pod::Spec.new do |s|
  s.name             = 'vv_native'
  s.version          = '0.1.0'
  s.summary          = 'VaultVoice native bridge (whisper.cpp + llama.cpp).'
  s.description      = 'Prebuilt xcframework with the vv_* C ABI.'
  s.homepage         = 'https://example.invalid/vaultvoice'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'VaultVoice' => 'noreply@example.invalid' }
  s.source           = { :path => '.' }
  s.dependency 'Flutter'
  s.platform = :ios, '16.4'
  s.vendored_frameworks = 'Frameworks/vv_native.xcframework'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
