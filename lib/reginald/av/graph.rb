module Reginald
  module AV
    class Graph
      attr_reader :pins

      def initialize(pins)
        @pins = pins
      end
    end
  end
end