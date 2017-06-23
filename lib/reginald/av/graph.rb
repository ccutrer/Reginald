module Reginald
  module AV
    class Graph
      attr_reader :possible_paths, :active_path

      def initialize(system, possible_paths)
        @system, @possible_paths = system, possible_paths
      end

      def conflicting_graphs
        conflicts_by_path = possible_paths.map { |path| conflicting_graphs_for(path) }
        return [] if conflicts_by_path.any?(&:empty?)
        conflicts_by_path.flatten.uniq
      end

      def start(interrupt: false)
        return if active_path

        conflicting_graphs = nil
        chosen_path = nil
        possible_paths.each do |path|
          chosen_path = path
          conflicting_graphs = conflicting_graphs_for(path)
          break if conflicting_graphs.empty?
        end

        raise PinInUse unless conflicting_graphs.empty? || interrupt
        conflicting_graphs.each(&:stop)
        @active_path = chosen_path
        @system.graphs << self
        active_path.first.graphs << self
        active_path[1...-1].each_slice(2) do |(input, output)|
          input.owner.switch_input(output, to: input)
          input.graphs << self
          output.graphs << self
        end
        active_path.last.graphs << self
      end

      def stop
        active_path.each do |pin|
          pin.graphs.delete(self)
        end
        @system.graphs.delete(self)
        @active_path = nil
      end

      private

      def conflicting_graphs_for(path)
        result = []
        path[1...-1].each_slice(2) do |(input, output)|
          result.concat(input.owner.conflicting_graphs_for(output, to: input))
        end
        result.uniq
      end
    end
  end
end