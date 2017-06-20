class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  around_action :with_singleton

  def with_singleton
    Reginald::AV::System.with_singleton do |system|
      @system = system
      yield
    end
  end

  def system
    @system
  end
  helper_method :system
end
