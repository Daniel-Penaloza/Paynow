class Admin::OrganizationsController < Admin::BaseController
  before_action :set_organization, only: %i[show edit update destroy]

  def index
    @organizations = Organization.order(:name)
  end

  def show
    @users = @organization.users
    @businesses_count  = @organization.businesses.count
    @monthly_receipts  = @organization.businesses
                           .joins(:receipts)
                           .where(receipts: { created_at: Date.current.beginning_of_month.. })
                           .count
  end

  def new
    @organization = Organization.new
  end

  def create
    @organization = Organization.new(organization_params)
    if @organization.save
      redirect_to admin_organization_path(@organization), notice: "Organización creada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @organization.update(organization_params)
      redirect_to admin_organization_path(@organization), notice: "Organización actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @organization.destroy
    redirect_to admin_organizations_path, notice: "Organización eliminada."
  end

  private

  def set_organization
    @organization = Organization.find(params[:id])
  end

  def organization_params
    params.require(:organization).permit(:name, :subdomain, :plan, :plan_status,
                                         :trial_ends_at, :current_period_ends_at)
  end
end
