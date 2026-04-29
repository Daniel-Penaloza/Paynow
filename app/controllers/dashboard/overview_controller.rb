class Dashboard::OverviewController < Dashboard::BaseController
  PER_PAGE_OPTIONS = [ 10, 20, 50, 100 ].freeze

  def index
    @businesses = Current.user.businesses.order(:name)

    @total_receipts       = Receipt.where(business: @businesses).count
    @today_receipts_count = Receipt.where(business: @businesses).today.count

    per_page = PER_PAGE_OPTIONS.include?(params[:per_page].to_i) ? params[:per_page].to_i : 10

    @recent_receipts = Receipt.where(business: @businesses)
                              .includes(:business)
                              .order(submitted_at: :desc)
                              .page(params[:page])
                              .per(per_page)
    @per_page = per_page
  end
end
