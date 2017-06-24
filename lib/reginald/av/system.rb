require 'active_support'
require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/module/delegation'

module Reginald
  module AV
    class System
      attr_reader :devices, :graphs
      delegate :synchronize, to: :mutex

      class << self
        def assign_instance(instance)
          @instance = instance
        end

        def with_singleton
          @instance.synchronize do
            yield(@instance)
          end
        end
      end

      def initialize(config)
        @devices = {}
        @graphs = []
        @mutex = Mutex.new

        config['devices'].each do |device_config|
          type = device_config['type']
          require "reginald/av/devices/#{type}"
          klass = Reginald::AV::Devices.const_get(ActiveSupport::Inflector.classify(type), false)
          device = klass.new(self, device_config)
          unless device.name
            count = devices.count { |_name, device| device.class == klass } + 1
            device.name = "#{type}#{count}"
          end
          devices[device.name] = device
        end

        devices.each_value do |device|
          Array.wrap(device.config['output']).each_with_index do |output, i|
            unless output.is_a?(Hash)
              output = { 'device' => output }
            end
            connected_device = devices[output['device']]
            raise UnknownDevice, "Could not find device #{output['device']} supposedly connected to #{device.name}" unless connected_device
            connected_pin = connected_device.find_input_pin(output)
            device.output_pins[i].connect(connected_pin)
          end
        end
      end

      def build_graph(source_device, sink_device)
        source_pin = source_device.output_pins.first
        sink_pin = sink_device.input_pins.first
        if (existing_graph = (sink_pin.graphs & source_pin.graphs).first)
          return existing_graph
        end
        possible_paths = find_paths(source_pin, sink_pin)
        return nil if possible_paths.empty?
        Graph.new(self, possible_paths)
      end

      def sources
        devices.values.select { |d| d.is_a?(Source) }
      end

      def visible_sources
        devices.values.select { |d| d.is_a?(Source) && !d.hidden? }
      end

      def sinks
        devices.values.select { |d| d.is_a?(Sink) }
      end

      private

      def mutex
        @mutex
      end

      def find_paths(source_pin, sink_pin)
        results = []
        sink_pin.owner.input_pins.each do |input|
          next unless input.connection
          results << [source_pin, input] if input.connection == source_pin
          result = find_paths(source_pin, input.connection)
          unless result.empty?
            result.each do |path|
              results << (path + [input.connection, input])
            end
          end
        end
        results
      end
    end
  end
end
