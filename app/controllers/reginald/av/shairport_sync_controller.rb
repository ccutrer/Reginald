# handle events from ShairportSync
class Reginald::Av::ShairportSyncController < ApplicationController
  before_action :find_device
  skip_before_action :verify_authenticity_token

  def create
    return render plain: "Instance Busy", status: 400 unless @device.output_pins.first.graphs.empty?

    return render plain: "Conflict occurred", status: 503 unless @device.start_graphs(system)

    result = 'OK'
    # if we're connected to a virtual matrix, we need to tell Shairport Sync which
    # device we ended up connected to
    pins = @device.output_pins.first.graphs.first&.active_path
    if pins.present? && pins[2].owner.is_a?(Reginald::AV::Devices::VirtualMatrix)
      result = pins[2].config['alsa_device'] || 'OK'
    end
    render plain: result
  end

  def destroy
    @device.stop

    render plain: 'OK'
  end

  private

  def find_device
    @device = system.devices[params[:id]]
    return render plain: "Device not found", status: 404 unless @device.is_a?(Reginald::AV::Devices::ShairportSync)
  end
end
