class Reginald::Av::GraphsController < ApplicationController
  def index
    render json: system.graphs.map(&:to_json)
  end
end
