Pod::Spec.new do |s|
  s.name             = 'AVMediaCache'
  s.version          = '1.5.0'
  s.summary          = 'A media cahce framework.'
  s.description      = <<-DESC
  a smart media cahce framework, help to cache media data when you see media play in your app at the same time.
                       DESC
                       
  s.homepage         = 'https://github.com/cocomanbar/AVMediaCache'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'tanxl' => '125322078@qq.com' }
  s.source           = { :git => 'https://github.com/cocomanbar/AVMediaCache.git', :tag => s.version.to_s }
  
  s.swift_version = '5.0'
  s.ios.deployment_target = '10.0'
  s.source_files = 'AVMediaCache/Classes/**/*'
  s.frameworks = 'UIKit', 'AVFoundation'
  
end
