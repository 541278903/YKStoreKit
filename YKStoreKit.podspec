
Pod::Spec.new do |s|
  s.name             = 'YKStoreKit'
  s.version          = '0.1.0'
  s.summary          = 'iOS 支付组件'

  s.description      = <<-DESC

      iOS 支付组件
      
                       DESC

  s.homepage         = 'https://github.com/541278903/YKStoreKit'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '541278903' => '534272374@qq.com' }
  s.source           = { :git => 'https://github.com/541278903/YKStoreKit.git', :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'

  s.source_files = 'YKStoreKit/Classes/**/*'
  
  s.frameworks = 'StoreKit','Foundation','CoreFoundation'
end
