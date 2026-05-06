require "rails_helper"

RSpec.describe Receipt, type: :model do

  # Desactivamos los callbacks de after_create_commit para los specs de modelo.
  # Razón: enqueue_verification llamaría al job real (Claude API) y
  # broadcast_to_dashboard intentaría usar ActionCable — ambos fuera de scope aquí.
  before do
    allow_any_instance_of(Receipt).to receive(:enqueue_verification)
    allow_any_instance_of(Receipt).to receive(:broadcast_to_dashboard)
    allow_any_instance_of(Receipt).to receive(:broadcast_remove_to)
  end

  # ─── Asociaciones ────────────────────────────────────────────────────────────
  describe "asociaciones" do
    it { is_expected.to belong_to(:business) }
  end

  # ─── Validaciones ────────────────────────────────────────────────────────────
  describe "validaciones" do
    # No usamos validate_presence_of(:submitted_at) con shoulda porque el
    # before_validation :set_submitted_at lo rellena automáticamente — el matcher
    # lo pone en nil, valida, y lo encuentra ya rellenado. Lo probamos manualmente abajo.

    describe "verification_status" do
      it "acepta valores válidos" do
        %w[pending verified rejected unreadable].each do |status|
          receipt = build(:receipt, verification_status: status)
          expect(receipt).to be_valid
        end
      end

      it "rechaza valores inválidos" do
        receipt = build(:receipt, verification_status: "desconocido")
        expect(receipt).not_to be_valid
      end
    end

    describe "payer_phone" do
      it "acepta un teléfono válido" do
        receipt = build(:receipt, payer_phone: "5512345678")
        expect(receipt).to be_valid
      end

      it "acepta campo vacío" do
        receipt = build(:receipt, payer_phone: "")
        expect(receipt).to be_valid
      end

      it "rechaza formato inválido" do
        receipt = build(:receipt, payer_phone: "abc")
        expect(receipt).not_to be_valid
        expect(receipt.errors[:payer_phone]).to be_present
      end
    end
  end

  # ─── Scopes ──────────────────────────────────────────────────────────────────
  # Los scopes son filtros reutilizables definidos en el modelo.
  # Aquí verificamos que devuelvan los registros correctos.
  describe "scopes de fecha" do
    let!(:receipt_hoy)      { create(:receipt, submitted_at: Time.current) }
    let!(:receipt_ayer)     { create(:receipt, submitted_at: 1.day.ago) }
    let!(:receipt_año_past) { create(:receipt, submitted_at: 1.year.ago) }

    # let! (con bang) crea el objeto inmediatamente, antes de que corra el ejemplo.
    # let (sin bang) es lazy — solo se crea cuando se referencia en el ejemplo.

    it ".today devuelve solo los de hoy" do
      expect(Receipt.today).to include(receipt_hoy)
      expect(Receipt.today).not_to include(receipt_ayer)
    end

    it ".this_week devuelve los de esta semana" do
      expect(Receipt.this_week).to include(receipt_hoy)
    end

    it ".this_year devuelve los de este año" do
      expect(Receipt.this_year).to include(receipt_hoy)
      expect(Receipt.this_year).not_to include(receipt_año_past)
    end
  end

  describe "scopes de status" do
    let!(:pendiente)    { create(:receipt, verification_status: "pending") }
    let!(:verificado)   { create(:receipt, :verified) }
    let!(:rechazado)    { create(:receipt, :rejected) }
    let!(:ilegible)     { create(:receipt, :unreadable) }

    it ".pending devuelve solo los pendientes" do
      expect(Receipt.pending).to include(pendiente)
      expect(Receipt.pending).not_to include(verificado)
    end

    it ".verified devuelve solo los verificados" do
      expect(Receipt.verified).to include(verificado)
      expect(Receipt.verified).not_to include(rechazado)
    end
  end

  # ─── Métodos de clase ────────────────────────────────────────────────────────
  describe ".total_amount_cents" do
    it "suma solo los comprobantes verificados" do
      create(:receipt, :verified, amount_cents: 10_000)
      create(:receipt, :verified, amount_cents: 20_000)
      create(:receipt, verification_status: "pending", amount_cents: 5_000)

      expect(Receipt.total_amount_cents).to eq(30_000)
    end
  end

  describe ".total_amount" do
    it "devuelve el total en pesos (dividido entre 100)" do
      create(:receipt, :verified, amount_cents: 45_000)
      expect(Receipt.total_amount).to eq(450.0)
    end
  end

  # ─── Métodos de instancia ────────────────────────────────────────────────────
  describe "#amount" do
    it "convierte amount_cents a pesos" do
      receipt = build(:receipt, :verified, amount_cents: 12_050)
      expect(receipt.amount).to eq(120.5)
    end

    it "devuelve nil si no hay amount_cents" do
      receipt = build(:receipt, amount_cents: nil)
      expect(receipt.amount).to be_nil
    end
  end

  describe "#amount=" do
    it "convierte pesos a centavos al asignar" do
      receipt = build(:receipt)
      receipt.amount = "250.50"
      expect(receipt.amount_cents).to eq(25_050)
    end

    it "asigna nil si el valor está vacío" do
      receipt = build(:receipt)
      receipt.amount = ""
      expect(receipt.amount_cents).to be_nil
    end
  end

  # ─── Callbacks ───────────────────────────────────────────────────────────────
  describe "before_validation :set_submitted_at" do
    it "asigna submitted_at automáticamente al crear si está en blanco" do
      receipt = build(:receipt, submitted_at: nil)
      receipt.valid?
      expect(receipt.submitted_at).to be_present
    end
  end
end
