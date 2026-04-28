class Dashboard::BaseController < ApplicationController
  layout "dashboard"

  before_action :require_business_owner

  private

  def require_business_owner
    redirect_to admin_root_path, alert: "No autorizado" unless Current.user&.business_owner?
  end

  def current_organization
    Current.user.organization
  end
end
