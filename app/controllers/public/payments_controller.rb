class Public::PaymentsController < ActionController::Base
  layout "public"

  before_action :set_organization
  before_action :set_business

  def show
    @whatsapp_url = build_whatsapp_url
    @submit_path  = build_submit_path
  end

  def submit_receipt
    unless @organization.within_receipt_limit?
      @submit_path  = build_submit_path
      @whatsapp_url = build_whatsapp_url
      flash.now[:alert] = "Este negocio ha alcanzado su límite mensual de comprobantes."
      return render :show, status: :unprocessable_entity
    end

    @receipt = @business.receipts.build(receipt_params.merge(submitted_at: Time.current))
    @receipt.file.attach(params[:file])

    if @receipt.save
      redirect_to build_show_path, notice: "Comprobante enviado correctamente."
    else
      @submit_path  = build_submit_path
      @whatsapp_url = build_whatsapp_url
      render :show, status: :unprocessable_entity
    end
  end

  private

  def receipt_params
    params.permit(:payer_name, :payer_phone)
  end

  def set_organization
    subdomain = params[:org_subdomain].presence || request.subdomain
    @organization = Organization.find_by!(subdomain: subdomain)
  rescue ActiveRecord::RecordNotFound
    render plain: "Organización no encontrada", status: :not_found
  end

  def set_business
    @business = @organization.businesses.find_by!(slug: params[:slug])
  rescue ActiveRecord::RecordNotFound
    render plain: "Negocio no encontrado", status: :not_found
  end

  def build_submit_path
    if params[:org_subdomain].present?
      dev_submit_receipt_path(org_subdomain: params[:org_subdomain], slug: @business.slug)
    else
      submit_receipt_path(@business.slug)
    end
  end

  def build_show_path
    if params[:org_subdomain].present?
      dev_pay_path(org_subdomain: params[:org_subdomain], slug: @business.slug)
    else
      pay_path(@business.slug)
    end
  end

  def build_whatsapp_url
    number = ENV["TWILIO_WHATSAPP_NUMBER"].to_s.gsub(/^whatsapp:\+?/, "")
    return nil if number.blank?

    text = CGI.escape("Comprobante para #{@business.slug}")
    "https://wa.me/#{number}?text=#{text}"
  end
end
