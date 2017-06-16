module Reginald
  module AV
    class Graph
      attr_reader :pins

      def initialize(system, pins)
        @system, @pins = system, pins
      end

      def conflicting_graphs
        result = []
        pins[1...-1].each_slice(2) do |(input, output)|
          result.concat(input.owner.conflicting_graphs_for(output, to: input))
        end
        result.uniq
      end

      def start(interrupt: false)
        conflicting_graphs = self.conflicting_graphs
        raise PinInUse unless conflicting_graphs.empty? || interrupt
        conflicting_graphs.each(&:stop)
        @system.graphs << self
        pins.first.graphs << self
        pins[1...-1].each_slice(2) do |(input, output)|
          input.owner.switch_input(output, to: input)
          input.graphs << self
          output.graphs << self
        end
        pins.last.graphs << self
      end

      def stop
        pins.each do |pin|
          pin.graphs.delete(self)
        end
        @system.graphs.delete(self)
      end
    end
  end
end