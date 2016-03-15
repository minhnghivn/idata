# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'idata/version'

Gem::Specification.new do |spec|
  spec.name          = "idata"
  spec.version       = Idata::VERSION
  spec.authors       = ["Nghi Pham"]
  spec.email         = ["minhnghivn@gmail.com"]
  spec.description   = %q{Included: iload, ivalidate, isanitize, ipatch, ieval, iexpor, ivalidate2}
  spec.summary       = %q{Data validation utilities}
  spec.homepage      = "https://github.com/minhnghivn/idata"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  #spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.executables  = ["iload", "ieval", "ipatch", "ivalidate", "iexport", "isanitize", "imerge", "ivalidate2"]
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
  
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake", "~> 10.0"

  #spec.add_dependency "rails", ">= 4.0"
  spec.add_dependency "pg", "~> 0.16"
end
