class Reginald::Av::GraphsController < ApplicationController
  def index
    respond_to do |format|
      format.json { render json: system.graphs.map(&:as_json) }
      format.html do
        render locals: { graphs: system.graphs }
      end
    end
  end

  def create
    source = system.devices[params[:source]]
    sink = system.devices[params[:sink]]
    unless source && sink
      return respond_to do |format|
        format.json { render json: { error: "could not find devices" }, status: 404 }
        format.html do
          flash[:error] = "Could not find devices"
          redirect_to :index
        end
      end
    end

    graph = system.build_graph(source, sink)
    unless params[:interrupt]
      conflicts = graph.conflicting_graphs
      unless conflicts.empty?
        return respond_to do |format|
          format.json { render json: { conflicts: conflicts.map(&:as_json) }, status: 422 }
          format.html do
            flash.now[:error] = "Graph would cause conflict"
            render :index, locals: { graphs: system.graphs }, status: 422
          end
        end
      end
    end

    graph.start(interrupt: params[:interrupt])

    respond_to do |format|
      format.json { render json: graph.as_json, status: 201 }
      format.html { redirect_to :av_graphs }
    end
  end

  def destroy
    graphs = system.graphs.select { |g| g.active_path.last.owner.name == params[:id] }
    if graphs.empty?
      return respond_to do |format|
        format.json { render json: [], status: 404 }
        format.html do
          flash[:error] = "Couldn't find graph"
          redirect_to :av_graphs
        end
      end
    end

    graphs.each(&:stop)

    respond_to do |format|
      format.json { render json: graphs.map(&:as_json) }
      format.html { redirect_to :av_graphs }
    end
  end
end
