class Dashboard::BusinessesController < Dashboard::BaseController
  before_action :set_business, only: %i[show edit update destroy qr]

  def index
    @businesses = Current.user.businesses.order(:name)
  end

  def show
    @recent_receipts = @business.receipts.order(submitted_at: :desc).limit(5)
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
