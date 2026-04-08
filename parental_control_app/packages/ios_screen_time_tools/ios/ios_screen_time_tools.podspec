Pod::Spec.new do |s|
  s.name             = 'ios_screen_time_tools'
  s.version          = '0.0.13'
  s.summary          = 'iOS Screen Time Tools Flutter plugin (local fork with native Screen Time actions)'
  s.description      = 'Family Controls picker, ManagedSettings shields, and usage stub.'
  s.homepage         = 'https://github.com/yourusername/ios_screen_time_tools'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'ParentalControl' => 'local' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '16.0'
  s.frameworks = 'FamilyControls', 'ManagedSettings', 'SwiftUI', 'UIKit', 'DeviceActivity', '_DeviceActivity_SwiftUI'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
