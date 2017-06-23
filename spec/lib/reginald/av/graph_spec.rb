require_relative "../../../spec_helper"

require 'yaml'

module Reginald::AV
  describe Graph do
    let(:system) { System.new(YAML.load(fixture("matrix_plus_receiver.yml"))) }
    let(:virtual_matrix) { System.new(YAML.load(fixture("virtual_matrix.yml"))) }

    describe "#start" do
      it "changes internal inputs" do
        graph = system.build_graph(system.devices['shairport_sync1'], system.devices['Kitchen'])
        graph.start
        amp = system.devices['monoprice_multizone_amp1']
        receiver = system.devices['pioneer_receiver1']
        expect(amp.output_pins[0].internal_connection).to eq amp.input_pins[1]
        expect(receiver.output_pins[1].internal_connection).to eq receiver.input_pins[0]
      end

      it "allows multiple non-conflicting graphs" do
        graph1 = system.build_graph(system.devices['shairport_sync1'], system.devices['Kitchen'])
        graph1.start
        graph2 = system.build_graph(system.devices['shairport_sync1'], system.devices['Living Room'])
        graph2.start
      end

      it "complains about conflicting graphs" do
        graph1 = system.build_graph(system.devices['shairport_sync1'], system.devices['Kitchen'])
        graph1.start
        graph2 = system.build_graph(system.devices['shairport_sync2'], system.devices['Living Room'])
        expect { graph2.start }.to raise_error(PinInUse)
      end

      it "chooses an available path" do
        system = virtual_matrix
        graph1 = system.build_graph(system.devices['shairport_sync_kitchen'], system.devices['Kitchen'])
        graph2 = system.build_graph(system.devices['shairport_sync_bedroom'], system.devices['Bedroom'])
        expect(graph1.possible_paths.length).to eq 2
        expect(graph1.possible_paths.length).to eq 2
        graph1.start
        expect(graph1.active_path).to eq graph1.possible_paths[0]
        graph2.start
        expect(graph2.active_path).to eq graph2.possible_paths[1]
      end
    end
  end
end
