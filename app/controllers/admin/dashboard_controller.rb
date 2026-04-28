class Admin::DashboardController < Admin::BaseController
  def index
    @organizations = Organization.all.order(:name)
  end
end
