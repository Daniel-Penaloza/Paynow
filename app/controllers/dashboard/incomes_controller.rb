class Dashboard::IncomesController < Dashboard::BaseController
  before_action :set_business

  PERIODS = %w[today this_week this_month this_year].freeze

  def index
    @period = PERIODS.include?(params[:period]) ? params[:period] : "this_month"

    @receipts = @business.receipts.verified
    @receipts = case @period
                when "today"      then @receipts.today
                when "this_week"  then @receipts.this_week
                when "this_month" then @receipts.this_month
                when "this_year"  then @receipts.this_year
                end

    @receipts = @receipts.order(Arel.sql("COALESCE(transfer_date, submitted_at::date) DESC, submitted_at DESC"))
    @total_amount = @receipts.total_amount
    @total_count  = @receipts.count

    respond_to do |format|
      format.html
      format.xlsx do
        period_label = {
          "today"      => "hoy",
          "this_week"  => "semana",
          "this_month" => "mes",
          "this_year"  => "año"
        }[@period]
        filename = "ingresos-#{@business.name.parameterize}-#{period_label}-#{Date.today}.xlsx"
        response.headers["Content-Disposition"] = "attachment; filename=\"#{filename}\""
      end
    end
  end

  private

  def set_business
    @business = Current.user.businesses.find(params[:business_id])
  end
end
