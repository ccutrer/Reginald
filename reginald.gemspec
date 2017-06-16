require_relative "lib/reginald/version"

Gem::Specification.new do |s|
  s.name        = "reginald"
  s.version     = Reginald::VERSION
  s.authors     = ["Cody Cutrer"]
  s.email       = ["cody@cutrer.us"]
  s.homepage    = "https://github.com/ccutrer/reginald"
  s.summary     = "My home automation musings"
  s.license     = "MIT"

  s.files = Dir["{lib}/**/*"] + ["Rakefile"]

  s.required_ruby_version = '>= 2.4'

  s.add_development_dependency "byebug", "~> 9"
  s.add_development_dependency "rake", "~> 12.0"
  s.add_development_dependency "rspec", "~> 3.6"
end
