class Admin::BaseController < ApplicationController
  layout "admin"

  before_action :require_super_admin

  private

  def require_super_admin
    redirect_to dashboard_root_path, alert: "No autorizado" unless Current.user&.super_admin?
  end
end
