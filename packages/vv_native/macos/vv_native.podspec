#
# Vends the prebuilt arm64 vv_native.framework produced by
# `native/build.sh macos`, which copies it to macos/Frameworks/ (gitignored).
# One ggml, Metal embedded. The Flutter macOS runner (app/macos, FND-09)
# embeds this framework into Contents/Frameworks via CocoaPods.
#
Pod::Spec.new do |s|
  s.name             = 'vv_native'
  s.version          = '0.1.0'
  s.summary          = 'VaultVoice native bridge (whisper.cpp + llama.cpp).'
  s.description      = 'Prebuilt macOS arm64 framework with the vv_* C ABI.'
  s.homepage         = 'https://example.invalid/vaultvoice'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'VaultVoice' => 'noreply@example.invalid' }
  s.source           = { :path => '.' }
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '13.0'
  s.vendored_frameworks = 'Frameworks/vv_native.framework'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
