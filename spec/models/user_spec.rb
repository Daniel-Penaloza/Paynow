require "rails_helper"

RSpec.describe User, type: :model do
  # ─── Asociaciones ────────────────────────────────────────────────────────────
  describe "asociaciones" do
    # belong_to(:organization).optional falla con business_owner porque las validaciones
    # custom del modelo rechazan esa combinación. Usamos super_admin como subject
    # ya que ese rol sí es válido sin organización.
    describe "organization es opcional a nivel de asociación" do
      subject { build(:user, :super_admin) }
      it { is_expected.to belong_to(:organization).optional }
    end

    it { is_expected.to have_many(:businesses).dependent(:destroy) }
    it { is_expected.to have_many(:sessions).dependent(:destroy) }
  end

  # ─── Validaciones ────────────────────────────────────────────────────────────
  describe "validaciones" do
    it { is_expected.to validate_presence_of(:role) }
  end

  # ─── Roles ───────────────────────────────────────────────────────────────────
  # Los enums de Rails generan métodos como super_admin? y business_owner?
  describe "roles" do
    # "subject" es la instancia que RSpec crea por defecto usando la factory.
    # let(:user) { create(:user) } sería equivalente pero subject es más conciso.

    it "business_owner es el rol por defecto" do
      user = build(:user)
      expect(user).to be_business_owner
    end

    it "puede ser super_admin" do
      user = build(:user, :super_admin)
      expect(user).to be_super_admin
    end
  end

  # ─── Validaciones por rol ────────────────────────────────────────────────────
  # Estas pruebas verifican las validaciones custom del modelo:
  # super_admin_has_no_organization y business_owner_has_organization
  describe "reglas de organización por rol" do
    context "cuando es business_owner" do
      it "es válido con organización" do
        user = build(:user)
        expect(user).to be_valid
      end

      it "no es válido sin organización" do
        # "context" agrupa pruebas bajo una condición específica.
        # Useful para separar casos de éxito y de error.
        user = build(:user, organization: nil)
        expect(user).not_to be_valid
        expect(user.errors[:organization]).to include("es requerida para dueños de negocio")
      end
    end

    context "cuando es super_admin" do
      it "es válido sin organización" do
        user = build(:user, :super_admin)
        expect(user).to be_valid
      end

      it "no es válido con organización" do
        org  = build(:organization)
        user = build(:user, :super_admin, organization: org)
        expect(user).not_to be_valid
        expect(user.errors[:organization]).to include("debe estar vacío para super admin")
      end
    end
  end

  # ─── Normalización del email ─────────────────────────────────────────────────
  describe "normalización del email" do
    it "guarda el email en minúsculas y sin espacios" do
      # create(:user) persiste en la BD de prueba (dentro de una transacción)
      # build(:user) solo construye el objeto en memoria sin guardar
      user = create(:user, email_address: "  USUARIO@EJEMPLO.COM  ")
      expect(user.email_address).to eq("usuario@ejemplo.com")
    end
  end
end
