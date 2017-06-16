require_relative "../../../spec_helper"

require 'yaml'

module Reginald::AV
  describe System do
    let(:direct_shairport_sync) { System.new(YAML.load(fixture("direct_shairport_sync.yml"))) }
    let(:basic_matrix) { System.new(YAML.load(fixture("basic_matrix.yml"))) }
    let(:matrix_plus_receiver) { System.new(YAML.load(fixture("matrix_plus_receiver.yml"))) }

    describe ".new" do
      it "parses a simple configuration" do
        system = direct_shairport_sync
        expect(system.devices.keys).to eq ['shairport_sync1', 'Kitchen']
        shairport = system.devices['shairport_sync1']
        expect(shairport.input_pins).to be_empty
        expect(shairport.output_pins.length).to eq 1
        speakers = system.devices['Kitchen']
        expect(speakers.input_pins.length).to eq 1
        expect(speakers.output_pins).to be_empty
        expect(shairport.output_pins.first.owner).to eq shairport
        expect(shairport.output_pins.first.connection).to eq speakers.input_pins.first
        expect(speakers.input_pins.first.owner).to eq speakers
        expect(speakers.input_pins.first.connection).to eq shairport.output_pins.first
      end

      it "parses a more complex configuration" do
        system = basic_matrix
        expect(system.devices.keys).to eq ['shairport_sync1', 'monoprice_multizone_amp1', 'Kitchen', 'Bedroom', 'Deck']
        shairport = system.devices['shairport_sync1']
        amp = system.devices['monoprice_multizone_amp1']
        expect(amp.input_pins.length).to eq 6
        expect(amp.output_pins.length).to eq 6
        expect(amp.input_pins[0].connection).to be_nil
        expect(amp.input_pins[1].connection.owner).to eq shairport
        expect(amp.input_pins[2].connection).to be_nil
        kitchen = system.devices['Kitchen']
        bedroom = system.devices['Bedroom']
        deck = system.devices['Deck']
        expect(amp.output_pins[0].connection.owner).to eq kitchen
        expect(amp.output_pins[1].connection.owner).to eq bedroom
        expect(amp.output_pins[2].connection.owner).to eq deck
        expect(amp.output_pins[3].connection).to be_nil
      end
    end

    describe "#build_graph" do
      it "builds a single step graph" do
        system = direct_shairport_sync
        shairport = system.devices['shairport_sync1']
        speakers = system.devices['Kitchen']
        graph = system.build_graph(shairport, speakers)
        expect(graph.pins).to eq [
                                     shairport.output_pins.first,
                                     speakers.input_pins.first
                                 ]
      end

      it "builds a two step graph" do
        system = basic_matrix
        shairport = system.devices['shairport_sync1']
        amp = system.devices['monoprice_multizone_amp1']
        speakers = system.devices['Deck']
        graph = system.build_graph(shairport, speakers)
        expect(graph.pins).to eq [
            shairport.output_pins.first,
            amp.input_pins[1],
            amp.output_pins[2],
            speakers.input_pins.first
                                 ]
      end

      it "builds a three step graph" do
        system = matrix_plus_receiver
        shairport = system.devices['shairport_sync1']
        amp = system.devices['monoprice_multizone_amp1']
        receiver = system.devices['pioneer_receiver1']
        speakers = system.devices['Kitchen']
        graph = system.build_graph(shairport, speakers)
        expect(graph.pins).to eq [
            shairport.output_pins.first,
            amp.input_pins[1],
            amp.output_pins[0],
            receiver.input_pins[0],
            receiver.output_pins[1],
            speakers.input_pins.first
                                 ]
      end
    end
  end
end
