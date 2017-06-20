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

  s.add_dependency "actionpack", "~> 5.1"
  s.add_dependency "actionview", "~> 5.1"
  s.add_dependency "activesupport", "~> 5.1"
  s.add_dependency "railties", "~> 5.1"
  s.add_dependency "puma", "~> 3.7"
  s.add_dependency "sprockets-rails", "~> 3.2"

  s.add_development_dependency "byebug", "~> 9"
  s.add_development_dependency "listen", "~> 3.1"
  s.add_development_dependency "rake", "~> 12.0"
  s.add_development_dependency "rspec", "~> 3.6"
end
