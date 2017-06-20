Rails.application.routes.draw do
  scope module: :reginald do
    namespace :av do
      resources :graphs, only: [:index, :create]
      delete "graph/:sink" => "graphs#destroy", as: "graph"
    end
  end
end
