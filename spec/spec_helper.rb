require 'byebug'
require 'rspec'

require 'reginald'

RSpec.configure do |config|
  config.raise_errors_for_deprecations!

  config.order = "random"
end

def fixture(name)
  File.read(File.expand_path(File.join(__FILE__, "../fixtures", name)))
end
