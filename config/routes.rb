Rails.application.routes.draw do
  scope module: :reginald do
    namespace :av do
      resources :graphs, only: :index
    end
  end
end
