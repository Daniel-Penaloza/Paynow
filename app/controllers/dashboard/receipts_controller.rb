class Dashboard::ReceiptsController < Dashboard::BaseController
  before_action :set_business

  def index
    @receipts = @business.receipts.order(submitted_at: :desc)
  end

  def show
    @receipt = @business.receipts.find(params[:id])
  end

  private

  def set_business
    @business = Current.user.businesses.find(params[:business_id])
  end
end
