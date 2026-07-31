require 'json'
package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name           = 'facetec-sdk-module'
  s.version        = package['version']
  s.summary        = package['description'] || 'Expo module bridging FaceTec 3D Face Authentication SDK'
  s.license        = package['license'] || 'MIT'
  s.author         = 'Alberta'
  s.homepage       = 'https://facetec.com'
  s.platform       = :ios, '14.0'
  s.swift_version  = '5.0'
  s.source         = { :path => '.' }

  s.source_files   = 'ios/*.swift', 'ios/FaceTecSDKBridge.{h,m}'

  s.frameworks = 'Foundation', 'UIKit', 'AVFoundation', 'CoreMotion', 'LocalAuthentication'

  s.pod_target_xcconfig = {
    'SWIFT_VERSION'                  => '5.0',
    'DEFINES_MODULE'                 => 'YES',
    'LD_RUNPATH_SEARCH_PATHS'        => '$(inherited) @executable_path/Frameworks',
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'YES',
    'STRIP_SWIFT_SYMBOLS'            => 'NO',
    'STRIP_STYLE'                    => 'non-global',
  }

  s.vendored_frameworks = 'ios/FaceTecSDK-ios-10.1.9/FaceTecSDK.xcframework'

  s.dependency 'ExpoModulesCore'
end
