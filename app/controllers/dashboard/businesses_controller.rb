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
    unless Current.user.organization.within_business_limit?
      return redirect_to new_dashboard_business_path,
        alert: "Has alcanzado el límite de negocios de tu plan. Contacta a soporte para hacer upgrade."
    end

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
    @qr = RQRCode::QRCode.new(payment_url_for(@business))
  end

  private

  def set_business
    @business = Current.user.businesses.find(params[:id])
  end

  # En desarrollo usa el host actual de la request (ngrok, lvh.me, etc.)
  # para que el QR siempre apunte a una URL accesible desde el dispositivo.
  # En producción delega al modelo que construye la URL con subdomain real.
  def payment_url_for(business)
    if Rails.env.development?
      dev_pay_url(
        org_subdomain: business.user.organization.subdomain,
        slug:          business.slug,
        host:          request.host,
        port:          request.port,
        protocol:      request.protocol
      )
    else
      business.public_url
    end
  end

  def business_params
    params.require(:business).permit(:name, :clabe, :holder_name, :whatsapp, :instructions)
  end
end
