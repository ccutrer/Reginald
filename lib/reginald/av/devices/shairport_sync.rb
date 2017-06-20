module Reginald
  module AV
    module Devices
      class ShairportSync < Source
        def initialize(config)
          super
          @output_pins = [Pin.new(self)]
        end

      end
    end
  end
end
