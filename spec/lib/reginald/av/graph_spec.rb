require_relative "../../../spec_helper"

require 'yaml'

module Reginald::AV
  describe Graph do
    let(:system) { System.new(YAML.load(fixture("matrix_plus_receiver.yml"))) }

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
    end
  end
end
