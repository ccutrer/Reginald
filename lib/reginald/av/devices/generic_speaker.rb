module Reginald
  module AV
    module Devices
      class GenericSpeaker < Sink
        def initialize(system, config)
          super
          @input_pins = [Pin.new(self)]
        end
      end
    end
  end
end