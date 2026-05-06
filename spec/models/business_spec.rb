require "rails_helper"

RSpec.describe Business, type: :model do

  # ─── Asociaciones ────────────────────────────────────────────────────────────
  describe "asociaciones" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:receipts).dependent(:destroy) }
  end

  # ─── Validaciones ────────────────────────────────────────────────────────────
  describe "validaciones" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:holder_name) }
    it { is_expected.to validate_presence_of(:clabe) }

    # validate_uniqueness_of necesita un registro ya persistido con asociaciones válidas.
    # subject le indica a shoulda-matchers qué instancia usar como base para la prueba.
    describe "unicidad del slug" do
      subject { create(:business) }
      it { is_expected.to validate_uniqueness_of(:slug) }
    end

    describe "CLABE" do
      it "debe tener exactamente 18 dígitos" do
        business = build(:business, clabe: "12345")
        expect(business).not_to be_valid
        expect(business.errors[:clabe]).to be_present
      end

      it "solo acepta dígitos" do
        business = build(:business, clabe: "12345678901234567A")
        expect(business).not_to be_valid
      end

      it "acepta una CLABE válida de 18 dígitos" do
        business = build(:business, clabe: "123456789012345678")
        expect(business).to be_valid
      end
    end
  end

  # ─── Generación del slug ─────────────────────────────────────────────────────
  # El slug se genera automáticamente en before_validation cuando está en blanco.
  describe "#generate_slug" do
    it "genera slug desde el nombre al crear" do
      business = create(:business, name: "Tacos El Gordo")
      expect(business.slug).to eq("tacos-el-gordo")
    end

    it "genera un slug único si ya existe uno igual" do
      # Creamos dos negocios con el mismo nombre para forzar el contador
      create(:business, name: "Tacos")
      business2 = create(:business, name: "Tacos")
      expect(business2.slug).to eq("tacos-1")
    end

    it "no sobreescribe un slug ya asignado" do
      business = create(:business, slug: "mi-slug-custom")
      expect(business.slug).to eq("mi-slug-custom")
    end
  end

  # ─── Métodos de instancia ────────────────────────────────────────────────────
  describe "#public_url" do
    it "devuelve una URL que incluye el slug del negocio" do
      business = create(:business)
      expect(business.public_url).to include(business.slug)
    end

    it "devuelve una URL que incluye el subdomain de la organización" do
      business = create(:business)
      expect(business.public_url).to include(business.user.organization.subdomain)
    end
  end
end
