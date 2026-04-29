class Dashboard::OverviewController < Dashboard::BaseController
  def index
    @businesses = Current.user.businesses.order(:name)
    @recent_receipts = Receipt.where(business: @businesses)
                              .includes(:business)
                              .order(submitted_at: :desc)
                              .limit(10)
    @total_receipts       = Receipt.where(business: @businesses).count
    @today_receipts_count = Receipt.where(business: @businesses).today.count
  end
end
