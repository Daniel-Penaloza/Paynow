require "rails_helper"

# Spec del CRUD de usuarios del panel super admin.
# Los usuarios viven anidados bajo organizaciones para create/new,
# pero tienen rutas propias para edit/update/destroy.
RSpec.describe "Admin::Users", type: :request do
  let(:super_admin)  { create(:user, :super_admin) }
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, organization: organization) }

  before { sign_in(super_admin) }

  # ─── Protección: sin autenticación ───────────────────────────────────────────
  describe "cuando el usuario NO está autenticado" do
    before { delete session_path }

    it "redirige al login al acceder a new" do
      get new_admin_organization_user_path(organization)
      expect(response).to redirect_to(new_session_path)
    end
  end

  # ─── Protección: business_owner no puede acceder ──────────────────────────────
  describe "cuando el usuario es business_owner (no super_admin)" do
    before do
      delete session_path
      sign_in(create(:user))
    end

    it "redirige al dashboard" do
      get new_admin_organization_user_path(organization)
      expect(response).to redirect_to(dashboard_root_path)
    end
  end

  # ─── GET /admin/organizations/:organization_id/users/new ─────────────────────
  describe "GET /admin/organizations/:organization_id/users/new" do
    it "devuelve 200" do
      get new_admin_organization_user_path(organization)
      expect(response).to have_http_status(:ok)
    end
  end

  # ─── POST /admin/organizations/:organization_id/users ────────────────────────
  describe "POST /admin/organizations/:organization_id/users" do
    let(:params_validos) do
      {
        user: {
          email_address:         "nuevo@ejemplo.com",
          password:              "secreto123",
          password_confirmation: "secreto123"
        }
      }
    end

    context "con parámetros válidos" do
      it "crea el usuario con rol business_owner y redirige al show de la org" do
        expect {
          post admin_organization_users_path(organization), params: params_validos
        }.to change(User, :count).by(1)

        nuevo = User.last
        expect(nuevo.organization).to eq(organization)
        expect(nuevo).to be_business_owner
        expect(response).to redirect_to(admin_organization_path(organization))
      end
    end

    context "con contraseñas que no coinciden" do
      it "devuelve 422 y no crea el usuario" do
        params_invalidos = { user: { email_address: "nuevo@ejemplo.com", password: "secreto123", password_confirmation: "diferente456" } }

        expect {
          post admin_organization_users_path(organization), params: params_invalidos
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # ─── GET /admin/users/:id/edit ────────────────────────────────────────────────
  describe "GET /admin/users/:id/edit" do
    it "devuelve 200" do
      get edit_admin_user_path(user)
      expect(response).to have_http_status(:ok)
    end
  end

  # ─── PATCH /admin/users/:id ───────────────────────────────────────────────────
  describe "PATCH /admin/users/:id" do
    context "con email válido" do
      it "actualiza el usuario y redirige al show de la org" do
        patch admin_user_path(user), params: {
          user: { email_address: "actualizado@ejemplo.com" }
        }
        expect(user.reload.email_address).to eq("actualizado@ejemplo.com")
        expect(response).to redirect_to(admin_organization_path(organization))
      end
    end

    context "con contraseñas que no coinciden" do
      it "devuelve 422" do
        patch admin_user_path(user), params: {
          user: { password: "nueva123", password_confirmation: "diferente456" }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "cuando la contraseña está en blanco" do
      it "actualiza el email sin cambiar la contraseña" do
        contrasena_original = user.password_digest
        patch admin_user_path(user), params: {
          user: { email_address: "nuevo@ejemplo.com", password: "", password_confirmation: "" }
        }
        expect(user.reload.password_digest).to eq(contrasena_original)
        expect(response).to redirect_to(admin_organization_path(organization))
      end
    end
  end

  # ─── DELETE /admin/users/:id ──────────────────────────────────────────────────
  describe "DELETE /admin/users/:id" do
    it "elimina el usuario y redirige al show de la org" do
      user

      expect {
        delete admin_user_path(user)
      }.to change(User, :count).by(-1)

      expect(response).to redirect_to(admin_organization_path(organization))
    end
  end
end
