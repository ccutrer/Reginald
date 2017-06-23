module Reginald
  module AV
    module Devices
      class ShairportSync < Source
        def initialize(config)
          super
          @output_pins = [Pin.new(self)]
        end

        def start_graphs(system)
          graphs = config['sinks'].map do |device_name|
            system.build_graph(self, system.devices[device_name])
          end

          return false if graphs.any? { |graph| !graph.conflicting_graphs.empty? }
          graphs.each(&:start)
          true
        end

        def hidden?
          output_pins.first.graphs.empty?
        end
      end
    end
  end
end
