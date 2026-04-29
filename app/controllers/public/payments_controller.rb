class Public::PaymentsController < ActionController::Base
  layout "public"

  before_action :set_organization
  before_action :set_business

  def show
  end

  def submit_receipt
    @receipt = @business.receipts.build(receipt_params.merge(submitted_at: Time.current))
    @receipt.file.attach(params[:file])

    if @receipt.save
      redirect_to pay_path(@business.slug), notice: "Comprobante enviado correctamente."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def receipt_params
    params.permit(:payer_name, :payer_phone)
  end

  def set_organization
    @organization = Organization.find_by!(subdomain: request.subdomain)
  rescue ActiveRecord::RecordNotFound
    render plain: "Organización no encontrada", status: :not_found
  end

  def set_business
    @business = @organization.businesses.find_by!(slug: params[:slug])
  rescue ActiveRecord::RecordNotFound
    render plain: "Negocio no encontrado", status: :not_found
  end
end
