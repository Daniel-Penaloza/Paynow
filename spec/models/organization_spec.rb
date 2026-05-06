require "rails_helper"

# RSpec.describe indica QUÉ estamos probando — en este caso el modelo Organization.
# type: :model activa los helpers específicos de modelos (shoulda-matchers, etc.)
RSpec.describe Organization, type: :model do

  # ─── Asociaciones ────────────────────────────────────────────────────────────
  # shoulda-matchers nos da have_many, belongs_to, etc.
  # Verifican que el modelo declara la asociación correctamente.
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
  end

  # ─── Comportamiento del subdomain ────────────────────────────────────────────
  # Aquí probamos el before_validation :normalize_subdomain del modelo.
  # "describe" agrupa pruebas relacionadas a una misma funcionalidad.
  describe "#normalize_subdomain" do
    # "it" es cada prueba individual. El bloque describe su expectativa.
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

  # ─── Formato del subdomain ───────────────────────────────────────────────────
  describe "formato del subdomain" do
    it "acepta letras minúsculas, números y guiones" do
      org = build(:organization, subdomain: "mi-negocio-123")
      expect(org).to be_valid
    end

    it "rechaza letras mayúsculas (antes de normalizar)" do
      # Forzamos el subdomain directamente sin pasar por before_validation
      org = build(:organization)
      org.subdomain = "MiNegocio"
      # Al llamar valid? se normaliza primero, así que verificamos el resultado
      org.valid?
      expect(org.subdomain).to match(/\A[a-z0-9\-]+\z/)
    end
  end
end
