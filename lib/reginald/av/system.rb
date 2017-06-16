require 'active_support'
require 'active_support/core_ext/array/wrap'

module Reginald
  module AV
    class System
      attr_reader :devices, :graphs

      def initialize(config)
        @devices = {}
        @graphs = []

        config['devices'].each do |device_config|
          type = device_config['type']
          require "reginald/av/devices/#{type}"
          klass = Reginald::AV::Devices.const_get(ActiveSupport::Inflector.classify(type), false)
          device = klass.new(device_config)
          unless device.name
            count = devices.count { |_name, device| device.class == klass } + 1
            device.name = "#{type}#{count}"
          end
          devices[device.name] = device
        end

        devices.each_value do |device|
          Array.wrap(device.config['output']).each_with_index do |output, i|
            if output.is_a?(Hash)
              connected_device_pin = output['input']
              output = output['device']
            end
            connected_device = devices[output]
            raise UnknownDevice, "Could not find device #{output} supposedly connected to #{device.name}" unless connected_device
            connected_pin = connected_device.find_input_pin(connected_device_pin || 1)
            device.output_pins[i].connect(connected_pin)
          end
        end
      end

      def build_graph(source_device, sink_device)
        source_pin = source_device.output_pins.first
        sink_pin = sink_device.input_pins.first
        pins = find_path(source_pin, sink_pin)
        return nil unless pins
        Graph.new(self, pins)
      end

      private

      def find_path(source_pin, sink_pin)
        sink_pin.owner.input_pins.each do |input|
          next unless input.connection
          return [source_pin, input] if input.connection == source_pin
          result = find_path(source_pin, input.connection)
          return result + [input.connection, input] if result
        end
        nil
      end
    end
  end
end
