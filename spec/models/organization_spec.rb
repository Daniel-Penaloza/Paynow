require "rails_helper"

RSpec.describe Organization, type: :model do
  # ─── Asociaciones ────────────────────────────────────────────────────────────
  describe "asociaciones" do
    it { is_expected.to have_many(:users).dependent(:destroy) }
    it { is_expected.to have_many(:businesses).through(:users) }
  end

  # ─── Validaciones ────────────────────────────────────────────────────────────
  describe "validaciones" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:subdomain) }

    it "rechaza subdomain duplicado" do
      create(:organization, subdomain: "mi-negocio")
      duplicado = build(:organization, subdomain: "mi-negocio")
      expect(duplicado).not_to be_valid
      expect(duplicado.errors[:subdomain]).to be_present
    end

    # MONETIZATION DISABLED: validación de plan comentada en el modelo
    xit "rechaza plan inválido" do
      org = build(:organization, plan: "enterprise")
      expect(org).not_to be_valid
      expect(org.errors[:plan]).to be_present
    end

    # MONETIZATION DISABLED: validación de plan_status comentada en el modelo
    xit "rechaza plan_status inválido" do
      org = build(:organization, plan_status: "suspended")
      expect(org).not_to be_valid
      expect(org.errors[:plan_status]).to be_present
    end

    it "acepta todos los planes válidos" do
      %w[free basic pro].each do |plan|
        expect(build(:organization, plan: plan)).to be_valid
      end
    end

    it "acepta todos los plan_status válidos" do
      %w[trialing active inactive].each do |status|
        expect(build(:organization, plan_status: status)).to be_valid
      end
    end
  end

  # ─── Defaults ────────────────────────────────────────────────────────────────
  describe "valores por defecto al crear" do
    it "asigna plan free por defecto" do
      org = create(:organization)
      expect(org.plan).to eq("free")
    end

    it "asigna plan_status trialing por defecto en el modelo" do
      # La factory usa :active para reflejar orgs existentes;
      # aquí probamos el default de la DB directamente
      org = Organization.new(name: "Test", subdomain: "test-default-#{rand(9999)}")
      expect(org.plan_status).to eq("trialing")
    end

    # MONETIZATION DISABLED: before_create :set_trial_end_date comentado en el modelo
    xit "asigna trial_ends_at a 365 días al crear" do
      org = create(:organization, plan_status: "trialing", trial_ends_at: nil)
      expect(org.trial_ends_at).to eq(365.days.from_now.to_date)
    end

    it "no sobreescribe trial_ends_at si ya viene asignado" do
      fecha = 100.days.from_now.to_date
      org = create(:organization, plan_status: "trialing", trial_ends_at: fecha)
      expect(org.trial_ends_at).to eq(fecha)
    end
  end

  # ─── Subdomain ───────────────────────────────────────────────────────────────
  describe "#normalize_subdomain" do
    it "convierte a minúsculas" do
      org = build(:organization, subdomain: "MiNegocio")
      org.valid?
      expect(org.subdomain).to eq("minegocio")
    end

    it "reemplaza espacios con guiones" do
      org = build(:organization, subdomain: "mi negocio")
      org.valid?
      expect(org.subdomain).to eq("mi-negocio")
    end

    it "elimina caracteres especiales" do
      org = build(:organization, subdomain: "mi@negocio!")
      org.valid?
      expect(org.subdomain).to eq("mi-negocio-")
    end
  end

  describe "formato del subdomain" do
    it "acepta letras minúsculas, números y guiones" do
      org = build(:organization, subdomain: "mi-negocio-123")
      expect(org).to be_valid
    end

    it "normaliza mayúsculas antes de validar formato" do
      org = build(:organization, subdomain: "MiNegocio")
      org.valid?
      expect(org.subdomain).to match(/\A[a-z0-9\-]+\z/)
    end
  end

  # ─── on_trial? ───────────────────────────────────────────────────────────────
  # MONETIZATION DISABLED: on_trial? siempre retorna false mientras la monetización está deshabilitada
  describe "#on_trial?" do
    xit "devuelve true si plan_status es trialing y trial_ends_at es futuro" do
      org = build(:organization, :trialing)
      expect(org.on_trial?).to be true
    end

    it "devuelve false si el trial ya expiró" do
      org = build(:organization, :trial_expired)
      expect(org.on_trial?).to be false
    end

    it "devuelve false si plan_status es active" do
      org = build(:organization, plan_status: "active", trial_ends_at: 365.days.from_now.to_date)
      expect(org.on_trial?).to be false
    end

    xit "devuelve true si trial_ends_at es hoy" do
      org = build(:organization, plan_status: "trialing", trial_ends_at: Date.current)
      expect(org.on_trial?).to be true
    end

    it "devuelve false si trial_ends_at es nil" do
      org = build(:organization, plan_status: "trialing", trial_ends_at: nil)
      expect(org.on_trial?).to be false
    end
  end

  # ─── plan_active? ────────────────────────────────────────────────────────────
  # MONETIZATION DISABLED: plan_active? siempre retorna true mientras la monetización está deshabilitada
  describe "#plan_active?" do
    it "devuelve true si plan_status es active" do
      org = build(:organization, plan_status: "active")
      expect(org.plan_active?).to be true
    end

    it "devuelve true si está en trial vigente" do
      org = build(:organization, :trialing)
      expect(org.plan_active?).to be true
    end

    xit "devuelve false si el trial expiró" do
      org = build(:organization, :trial_expired)
      expect(org.plan_active?).to be false
    end

    xit "devuelve false si plan_status es inactive" do
      org = build(:organization, :inactive)
      expect(org.plan_active?).to be false
    end
  end

  # ─── within_business_limit? ──────────────────────────────────────────────────
  # MONETIZATION DISABLED: within_business_limit? siempre retorna true
  describe "#within_business_limit?" do
    context "plan free (límite 1 negocio)" do
      it "devuelve true cuando no tiene negocios" do
        org = create(:organization)
        expect(org.within_business_limit?).to be true
      end

      xit "devuelve false cuando ya alcanzó el límite" do
        user = create(:user, :business_owner)
        org  = user.organization
        create(:business, user: user)
        expect(org.within_business_limit?).to be false
      end
    end

    context "plan pro (límite 5 negocios)" do
      it "devuelve true con 4 negocios" do
        user = create(:user, :business_owner)
        org  = user.organization
        org.update!(plan: "pro")
        4.times { create(:business, user: user) }
        expect(org.within_business_limit?).to be true
      end

      xit "devuelve false con 5 negocios" do
        user = create(:user, :business_owner)
        org  = user.organization
        org.update!(plan: "pro")
        5.times { create(:business, user: user) }
        expect(org.within_business_limit?).to be false
      end
    end
  end

  # ─── within_receipt_limit? ───────────────────────────────────────────────────
  # MONETIZATION DISABLED: within_receipt_limit? siempre retorna true
  describe "#within_receipt_limit?" do
    context "plan pro (ilimitado)" do
      it "siempre devuelve true" do
        org = create(:organization, :pro)
        expect(org.within_receipt_limit?).to be true
      end
    end

    context "plan free (límite 50 comprobantes/mes)" do
      it "devuelve true cuando no hay comprobantes este mes" do
        org = create(:organization)
        expect(org.within_receipt_limit?).to be true
      end

      xit "devuelve false cuando se alcanzó el límite mensual" do
        user     = create(:user, :business_owner)
        org      = user.organization
        business = create(:business, user: user)
        create_list(:receipt, 50, business: business, created_at: Date.current.beginning_of_month + 1.hour)
        expect(org.within_receipt_limit?).to be false
      end

      it "no cuenta comprobantes del mes anterior" do
        user     = create(:user, :business_owner)
        org      = user.organization
        business = create(:business, user: user)
        create_list(:receipt, 50, business: business, created_at: 1.month.ago)
        expect(org.within_receipt_limit?).to be true
      end
    end
  end
end
