class Dashboard::ReceiptsController < Dashboard::BaseController
  before_action :set_business

  def index
    @receipts = @business.receipts
    @period = params[:period]
    @date_from = params[:date_from]
    @date_to = params[:date_to]

    @receipts = case @period
                when "today"      then @receipts.today
                when "this_week"  then @receipts.this_week
                when "this_month" then @receipts.this_month
                when "this_year"  then @receipts.this_year
                else
                  if @date_from.present? && @date_to.present?
                    from = Date.parse(@date_from) rescue nil
                    to   = Date.parse(@date_to)   rescue nil
                    from && to ? @receipts.between(from, to) : @receipts
                  else
                    @receipts
                  end
                end

    @receipts = @receipts.order(submitted_at: :desc)
    @total_count = @receipts.count
  end

  def show
    @receipt = @business.receipts.find(params[:id])
  end

  private

  def set_business
    @business = Current.user.businesses.find(params[:business_id])
  end
end
