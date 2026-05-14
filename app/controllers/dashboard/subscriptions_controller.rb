class Dashboard::SubscriptionsController < Dashboard::BaseController
  # MONETIZATION DISABLED — este controlador no se usa mientras los planes están deshabilitados
  def show
    @organization = Current.user.organization
    # @monthly_receipts = Receipt
    #   .where(business: Current.user.businesses)
    #   .where(created_at: Date.current.beginning_of_month..)
    #   .count
    # @receipt_limit  = Organization::PLAN_LIMITS[@organization.plan][:receipts_per_month]
    # @business_limit = Organization::PLAN_LIMITS[@organization.plan][:businesses]
  end
end
