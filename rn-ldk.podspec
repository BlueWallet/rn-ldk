require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "rn-ldk"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "13.0" }
  s.source       = { :git => "https://github.com/Overtorment/rn-ldk.git", :tag => "#{s.version}" }

  
  s.source_files = "ios/*.{h,m,mm,swift}"
  

  s.dependency "React-Core"
  s.vendored_frameworks = "ios/LightningDevKit.xcframework"
end
