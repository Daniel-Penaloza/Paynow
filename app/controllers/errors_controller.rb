class ErrorsController < ActionController::Base
  layout "public"

  def not_found
    render status: :not_found
  end
end
