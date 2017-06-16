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
    end
  end
end
