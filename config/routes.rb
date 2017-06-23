Rails.application.routes.draw do
  scope module: :reginald do
    namespace :av do
      resources :graphs, only: [:index, :create]
      delete "graph/:sink" => "graphs#destroy", as: "graph"

      post "shairport_sync/:id" => "shairport_sync#create"
    end
  end
end
