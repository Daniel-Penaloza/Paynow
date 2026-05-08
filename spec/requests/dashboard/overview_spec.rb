require "rails_helper"

RSpec.describe "Dashboard::Overview", type: :request do
  let(:user)     { create(:user) }
  let(:business) { create(:business, user: user) }

  before do
    sign_in(user)
    allow_any_instance_of(Receipt).to receive(:enqueue_verification)
    allow_any_instance_of(Receipt).to receive(:broadcast_to_dashboard)
    allow_any_instance_of(Receipt).to receive(:broadcast_remove_to)
  end

  # ─── Protección de autenticación ─────────────────────────────────────────────
  describe "cuando el usuario NO está autenticado" do
    before { delete session_path }

    it "redirige al login" do
      get dashboard_root_path
      expect(response).to redirect_to(new_session_path)
    end
  end

  # ─── GET /dashboard ───────────────────────────────────────────────────────────
  describe "GET /dashboard" do
    it "devuelve 200" do
      get dashboard_root_path
      expect(response).to have_http_status(:ok)
    end

    it "muestra los negocios del usuario" do
      business
      get dashboard_root_path
      expect(response.body).to include(business.name)
    end
  end

  # ─── Widget de uso ───────────────────────────────────────────────────────────
  describe "widget de uso" do
    it "muestra el plan de la organización" do
      get dashboard_root_path
      expect(response.body).to include("Uso del plan")
      expect(response.body).to include("Free")
    end

    it "muestra el contador de comprobantes del mes" do
      create(:receipt, business: business, created_at: Time.current)
      get dashboard_root_path
      expect(response.body).to include("Comprobantes este mes")
      expect(response.body).to include("1 / 50")
    end

    it "no cuenta comprobantes del mes anterior" do
      create(:receipt, business: business, created_at: 1.month.ago)
      get dashboard_root_path
      expect(response.body).to include("0 / 50")
    end

    it "muestra el contador de negocios" do
      business
      get dashboard_root_path
      expect(response.body).to include("Negocios")
      expect(response.body).to include("1 / 1")
    end

    context "cuando se alcanzó el límite mensual de comprobantes" do
      it "muestra el banner de límite alcanzado" do
        create_list(:receipt, 50, business: business, created_at: Time.current)
        get dashboard_root_path
        expect(response.body).to include("Límite alcanzado")
      end
    end

    context "cuando queda menos del 20% de cuota (plan free, 41+ comprobantes)" do
      it "muestra el banner de cuota casi agotada" do
        create_list(:receipt, 41, business: business, created_at: Time.current)
        get dashboard_root_path
        expect(response.body).to include("Cuota casi agotada")
      end
    end

    context "con plan pro (comprobantes ilimitados)" do
      before { user.organization.update!(plan: "pro") }

      it "muestra ∞ como límite" do
        get dashboard_root_path
        expect(response.body).to include("∞")
      end

      it "no muestra barra de progreso de comprobantes" do
        get dashboard_root_path
        expect(response.body).not_to include("Límite alcanzado")
        expect(response.body).not_to include("Cuota casi agotada")
      end
    end
  end
end
