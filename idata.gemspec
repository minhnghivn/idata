# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'idata/version'

Gem::Specification.new do |spec|
  spec.name          = "idata"
  spec.version       = Idata::VERSION
  spec.authors       = ["Nghi Pham"]
  spec.email         = ["minhnghivn@gmail.com"]
  spec.description   = %q{Tools for importing data from raw files}
  spec.summary       = %q{Tools include: iload, ivalidate, isanitize, ipatch, ieval, iexport}
  spec.homepage      = "http://bolero.vn"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  #spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.executables  = ["iload", "ieval", "ipatch", "ivalidate", "iexport", "isanitize", "imerge"]
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
  
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_dependency "rails", "~> 4.0"
  spec.add_dependency "pg", "~> 0.16"
end
