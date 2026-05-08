class Dashboard::OverviewController < Dashboard::BaseController
  PER_PAGE_OPTIONS = [ 10, 20, 50, 100 ].freeze

  def index
    @businesses   = Current.user.businesses.order(:name)
    @organization = Current.user.organization

    @total_receipts       = Receipt.where(business: @businesses).count
    @today_receipts_count = Receipt.where(business: @businesses).today.count

    @monthly_receipts = Receipt
      .where(business: @businesses)
      .where(created_at: Date.current.beginning_of_month..)
      .count
    @receipt_limit  = Organization::PLAN_LIMITS[@organization.plan][:receipts_per_month]
    @business_limit = Organization::PLAN_LIMITS[@organization.plan][:businesses]

    per_page = PER_PAGE_OPTIONS.include?(params[:per_page].to_i) ? params[:per_page].to_i : 10

    @recent_receipts = Receipt.where(business: @businesses)
                              .includes(:business)
                              .order(submitted_at: :desc)
                              .page(params[:page])
                              .per(per_page)
    @per_page = per_page
  end
end
