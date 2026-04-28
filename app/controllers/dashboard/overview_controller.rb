class Dashboard::OverviewController < Dashboard::BaseController
  def index
    @businesses = Current.user.businesses.order(:name)
    @recent_receipts = Receipt.where(business: @businesses).order(submitted_at: :desc).limit(10)
  end
end
