class Dashboard::BusinessesController < Dashboard::BaseController
  before_action :set_business, only: %i[show edit update destroy qr]

  def index
    @businesses = Current.user.businesses.order(:name)
  end

  def show
    @recent_receipts = @business.receipts.order(submitted_at: :desc).limit(5)

    receipts = @business.receipts
    @totals = {
      today:            receipts.today.total_amount,
      this_week:        receipts.this_week.total_amount,
      this_month:       receipts.this_month.total_amount,
      this_year:        receipts.this_year.total_amount,
      today_count:      receipts.today.verified.count,
      this_week_count:  receipts.this_week.verified.count,
      this_month_count: receipts.this_month.verified.count,
      this_year_count:  receipts.this_year.verified.count
    }
  end

  def new
    @business = Current.user.businesses.build
  end

  def create
    @business = Current.user.businesses.build(business_params)
    if @business.save
      redirect_to dashboard_business_path(@business), notice: "Negocio creado correctamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @business.update(business_params)
      redirect_to dashboard_business_path(@business), notice: "Negocio actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @business.destroy
    redirect_to dashboard_businesses_path, notice: "Negocio eliminado."
  end

  def qr
    @qr = @business.qr_code
  end

  private

  def set_business
    @business = Current.user.businesses.find(params[:id])
  end

  def business_params
    params.require(:business).permit(:name, :clabe, :holder_name, :whatsapp, :instructions)
  end
end
