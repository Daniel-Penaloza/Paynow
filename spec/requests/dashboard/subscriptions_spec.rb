require "rails_helper"

RSpec.describe "Dashboard::Subscriptions", type: :request do
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
      get dashboard_subscription_path
      expect(response).to redirect_to(new_session_path)
    end
  end

  # ─── GET /dashboard/subscription ─────────────────────────────────────────────
  describe "GET /dashboard/subscription" do
    it "devuelve 200" do
      get dashboard_subscription_path
      expect(response).to have_http_status(:ok)
    end

    it "muestra el plan actual" do
      get dashboard_subscription_path
      expect(response.body).to include("Plan actual")
      expect(response.body).to include("Free")
    end

    it "muestra el status del plan" do
      get dashboard_subscription_path
      expect(response.body).to include("Activo")
    end

    it "muestra el uso de comprobantes del mes" do
      create(:receipt, business: business, created_at: Time.current)
      get dashboard_subscription_path
      expect(response.body).to include("Comprobantes recibidos")
      expect(response.body).to include("1 / 50")
    end

    it "muestra el uso de negocios" do
      business
      get dashboard_subscription_path
      expect(response.body).to include("Negocios registrados")
      expect(response.body).to include("1 / 1")
    end

    it "muestra los planes disponibles" do
      get dashboard_subscription_path
      expect(response.body).to include("Básico")
      expect(response.body).to include("Pro")
      expect(response.body).to include("$199")
      expect(response.body).to include("$349")
    end

    context "con plan pro (comprobantes ilimitados)" do
      before { user.organization.update!(plan: "pro") }

      it "muestra ∞ como límite de comprobantes" do
        get dashboard_subscription_path
        expect(response.body).to include("∞")
      end

      it "marca el plan Pro como plan actual" do
        get dashboard_subscription_path
        expect(response.body).to include("Plan actual")
      end
    end

    context "cuando hay fecha de trial vigente" do
      before do
        user.organization.update!(plan_status: "trialing",
                                  trial_ends_at: 30.days.from_now.to_date)
      end

      it "muestra la fecha de fin del trial" do
        get dashboard_subscription_path
        expect(response.body).to include("Fin del período de prueba")
      end
    end
  end

  # ─── Banner de trial en el layout ────────────────────────────────────────────
  describe "banner de trial" do
    context "cuando la organización está en trial vigente" do
      before do
        user.organization.update!(plan_status: "trialing",
                                  trial_ends_at: 10.days.from_now.to_date)
      end

      it "muestra el banner con los días restantes en el dashboard" do
        get dashboard_root_path
        expect(response.body).to include("período de prueba")
        expect(response.body).to include("10 días")
        expect(response.body).to include("Ver planes")
      end
    end

    context "cuando el trial expira hoy" do
      before do
        user.organization.update!(plan_status: "trialing",
                                  trial_ends_at: Date.current)
      end

      it "muestra 'termina hoy'" do
        get dashboard_root_path
        expect(response.body).to include("hoy")
      end
    end

    context "cuando la organización tiene plan active (no trial)" do
      it "no muestra el banner de trial" do
        get dashboard_root_path
        expect(response.body).not_to include("período de prueba")
      end
    end

    context "cuando el trial ya expiró" do
      before do
        user.organization.update!(plan_status: "trialing",
                                  trial_ends_at: 1.day.ago.to_date)
      end

      it "no muestra el banner de trial" do
        get dashboard_root_path
        expect(response.body).not_to include("período de prueba")
      end
    end
  end
end
