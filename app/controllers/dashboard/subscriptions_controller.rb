class Dashboard::SubscriptionsController < Dashboard::BaseController
  def show
    @organization = Current.user.organization
    @monthly_receipts = Receipt
      .where(business: Current.user.businesses)
      .where(created_at: Date.current.beginning_of_month..)
      .count
    @receipt_limit  = Organization::PLAN_LIMITS[@organization.plan][:receipts_per_month]
    @business_limit = Organization::PLAN_LIMITS[@organization.plan][:businesses]
  end
end
