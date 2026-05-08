require "rails_helper"

# Spec del CRUD de organizaciones del panel super admin.
# Verificamos tres dimensiones:
#   1. Acceso denegado a usuarios no autenticados → redirige al login
#   2. Acceso denegado a business_owners → redirige al dashboard (no son super_admin)
#   3. Respuestas HTTP correctas para cada acción cuando el super_admin está autenticado
RSpec.describe "Admin::Organizations", type: :request do

  let(:super_admin)  { create(:user, :super_admin) }
  let(:organization) { create(:organization) }

  before { sign_in(super_admin) }

  # ─── Protección: sin autenticación ───────────────────────────────────────────
  describe "cuando el usuario NO está autenticado" do
    before { delete session_path }

    it "redirige al login" do
      get admin_organizations_path
      expect(response).to redirect_to(new_session_path)
    end
  end

  # ─── Protección: business_owner no puede acceder ──────────────────────────────
  describe "cuando el usuario es business_owner (no super_admin)" do
    before do
      delete session_path
      sign_in(create(:user))
    end

    it "redirige al dashboard con alerta" do
      get admin_organizations_path
      expect(response).to redirect_to(dashboard_root_path)
    end
  end

  # ─── GET /admin/organizations — índice ───────────────────────────────────────
  describe "GET /admin/organizations" do

    it "devuelve 200" do
      get admin_organizations_path
      expect(response).to have_http_status(:ok)
    end

    it "muestra todas las organizaciones" do
      organization
      get admin_organizations_path
      expect(response.body).to include(organization.name)
    end
  end

  # ─── GET /admin/organizations/new ────────────────────────────────────────────
  describe "GET /admin/organizations/new" do

    it "devuelve 200" do
      get new_admin_organization_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ─── POST /admin/organizations ───────────────────────────────────────────────
  describe "POST /admin/organizations" do

    let(:params_validos) do
      { organization: { name: "Tacos El Güero", subdomain: "tacos-el-guero" } }
    end

    context "con parámetros válidos" do
      it "crea la organización y redirige al show" do
        expect {
          post admin_organizations_path, params: params_validos
        }.to change(Organization, :count).by(1)

        expect(response).to redirect_to(admin_organization_path(Organization.last))
      end
    end

    context "con parámetros inválidos (nombre vacío)" do
      it "devuelve 422 y re-renderiza el formulario" do
        params_invalidos = { organization: { name: "", subdomain: "algo" } }

        expect {
          post admin_organizations_path, params: params_invalidos
        }.not_to change(Organization, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # ─── GET /admin/organizations/:id — detalle ──────────────────────────────────
  describe "GET /admin/organizations/:id" do

    it "devuelve 200 y muestra la organización" do
      get admin_organization_path(organization)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(organization.name)
    end

    it "muestra el plan y status de la organización" do
      get admin_organization_path(organization)
      expect(response.body).to include("Plan y uso")
      expect(response.body).to include("Free")
      expect(response.body).to include("Activo")
    end

    it "muestra el uso del mes (negocios y comprobantes)" do
      user     = create(:user, :business_owner, organization: organization)
      business = create(:business, user: user)
      create(:receipt, business: business, created_at: Time.current)

      get admin_organization_path(organization)

      expect(response.body).to include("Negocios")
      expect(response.body).to include("Comprobantes este mes")
    end
  end

  # ─── GET /admin/organizations/:id/edit ───────────────────────────────────────
  describe "GET /admin/organizations/:id/edit" do

    it "devuelve 200" do
      get edit_admin_organization_path(organization)
      expect(response).to have_http_status(:ok)
    end
  end

  # ─── PATCH /admin/organizations/:id ──────────────────────────────────────────
  describe "PATCH /admin/organizations/:id" do

    context "con datos válidos" do
      it "actualiza la organización y redirige al show" do
        patch admin_organization_path(organization), params: {
          organization: { name: "Nombre Actualizado" }
        }
        expect(organization.reload.name).to eq("Nombre Actualizado")
        expect(response).to redirect_to(admin_organization_path(organization))
      end
    end

    context "con datos inválidos" do
      it "devuelve 422" do
        patch admin_organization_path(organization), params: {
          organization: { name: "" }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "asignando plan manualmente" do
      it "actualiza plan y plan_status" do
        fecha = 30.days.from_now.to_date
        patch admin_organization_path(organization), params: {
          organization: {
            plan:                    "pro",
            plan_status:             "active",
            current_period_ends_at:  fecha.to_s
          }
        }
        organization.reload
        expect(organization.plan).to eq("pro")
        expect(organization.plan_status).to eq("active")
        expect(organization.current_period_ends_at).to eq(fecha)
        expect(response).to redirect_to(admin_organization_path(organization))
      end

      it "actualiza trial_ends_at" do
        fecha = 365.days.from_now.to_date
        patch admin_organization_path(organization), params: {
          organization: { plan_status: "trialing", trial_ends_at: fecha.to_s }
        }
        organization.reload
        expect(organization.plan_status).to eq("trialing")
        expect(organization.trial_ends_at).to eq(fecha)
      end
    end
  end

  # ─── DELETE /admin/organizations/:id ─────────────────────────────────────────
  describe "DELETE /admin/organizations/:id" do

    it "elimina la organización y redirige al índice" do
      organization

      expect {
        delete admin_organization_path(organization)
      }.to change(Organization, :count).by(-1)

      expect(response).to redirect_to(admin_organizations_path)
    end
  end
end
