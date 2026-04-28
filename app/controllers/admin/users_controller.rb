class Admin::UsersController < Admin::BaseController
  before_action :set_organization, only: %i[new create]
  before_action :set_user, only: %i[edit update destroy]

  def new
    @user = @organization.users.build
  end

  def create
    @user = @organization.users.build(user_params)
    @user.role = :business_owner

    if @user.save
      redirect_to admin_organization_path(@organization), notice: "Usuario creado correctamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @organization = @user.organization
  end

  def update
    if @user.update(update_params)
      redirect_to admin_organization_path(@user.organization), notice: "Usuario actualizado."
    else
      @organization = @user.organization
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    organization = @user.organization
    @user.destroy
    redirect_to admin_organization_path(organization), notice: "Usuario eliminado."
  end

  private

  def set_organization
    @organization = Organization.find(params[:organization_id])
  end

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email_address, :password, :password_confirmation)
  end

  def update_params
    permitted = params.require(:user).permit(:email_address, :password, :password_confirmation)
    permitted.delete(:password) if permitted[:password].blank?
    permitted.delete(:password_confirmation) if permitted[:password_confirmation].blank?
    permitted
  end
end
