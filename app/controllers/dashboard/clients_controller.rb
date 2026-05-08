class Dashboard::ClientsController < Dashboard::BaseController
  before_action :set_business

  def index
    @clients = @business.receipts
                        .where.not(payer_phone: [ nil, "" ])
                        .verified
                        .select("payer_name, payer_phone, COUNT(*) AS receipt_count, SUM(amount_cents) AS total_cents, MAX(submitted_at) AS last_seen")
                        .group(:payer_phone, :payer_name)
                        .order("last_seen DESC")
  end

  private

  def set_business
    @business = Current.user.businesses.find(params[:business_id])
  end
end
