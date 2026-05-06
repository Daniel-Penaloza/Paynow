require "rails_helper"

# Spec del controlador de comprobantes del dashboard.
# Lo interesante aquí:
#   - El filtro de período (today, this_week, etc.) afecta qué receipts aparecen
#   - La acción `reprocess` encola un job y responde con Turbo Stream o redirect
#   - Toda acción requiere autenticación y que el negocio pertenezca al usuario
RSpec.describe "Dashboard::Receipts", type: :request do

  let(:user)     { create(:user) }
  let(:business) { create(:business, user: user) }

  before do
    sign_in(user)
    # Silenciamos callbacks de Receipt que dependen de servicios externos
    allow_any_instance_of(Receipt).to receive(:enqueue_verification)
    allow_any_instance_of(Receipt).to receive(:broadcast_to_dashboard)
    allow_any_instance_of(Receipt).to receive(:broadcast_remove_to)
  end

  # ─── GET /dashboard/businesses/:business_id/receipts — índice ────────────────
  describe "GET /dashboard/businesses/:business_id/receipts" do

    it "devuelve 200" do
      get dashboard_business_receipts_path(business)
      expect(response).to have_http_status(:ok)
    end

    context "con filtro period: 'today'" do
      let!(:receipt_hoy)  { create(:receipt, business: business, submitted_at: Time.current) }
      let!(:receipt_ayer) { create(:receipt, business: business, submitted_at: 1.day.ago) }

      it "solo muestra los comprobantes de hoy" do
        get dashboard_business_receipts_path(business), params: { period: "today" }
        # La vista de índice muestra links a cada receipt — verificamos por el ID en la URL
        expect(response.body).to include("/receipts/#{receipt_hoy.id}")
        expect(response.body).not_to include("/receipts/#{receipt_ayer.id}")
      end
    end

    context "con filtro de rango de fechas personalizado" do
      let!(:receipt_en_rango)    { create(:receipt, business: business, submitted_at: 3.days.ago) }
      let!(:receipt_fuera_rango) { create(:receipt, business: business, submitted_at: 10.days.ago) }

      it "filtra por date_from y date_to" do
        get dashboard_business_receipts_path(business), params: {
          date_from: 5.days.ago.to_date.to_s,
          date_to:   1.day.ago.to_date.to_s
        }
        expect(response.body).to include("/receipts/#{receipt_en_rango.id}")
        expect(response.body).not_to include("/receipts/#{receipt_fuera_rango.id}")
      end
    end
  end

  # ─── GET /dashboard/businesses/:business_id/receipts/:id — detalle ───────────
  describe "GET /dashboard/businesses/:business_id/receipts/:id" do

    # Usamos :verified para que la vista muestre payer_name.
    # El show.html.erb solo renderiza detalles (incluyendo payer_name) cuando
    # verification_status != "pending".
    let!(:receipt) { create(:receipt, :verified, business: business) }

    it "devuelve 200" do
      get dashboard_business_receipt_path(business, receipt)
      expect(response).to have_http_status(:ok)
    end

    it "muestra la información del comprobante" do
      get dashboard_business_receipt_path(business, receipt)
      expect(response.body).to include(receipt.payer_name)
    end
  end

  # ─── POST /dashboard/businesses/:business_id/receipts/:id/reprocess ──────────
  describe "POST reprocess" do

    let!(:receipt) { create(:receipt, :verified, business: business) }

    # Stub del job para no ejecutarlo realmente
    before { allow(ReceiptVerificationJob).to receive(:perform_later) }

    context "con formato HTML" do
      it "resetea el status a 'pending'" do
        post reprocess_dashboard_business_receipt_path(business, receipt)
        expect(receipt.reload.verification_status).to eq("pending")
      end

      it "encola ReceiptVerificationJob con force: true" do
        expect(ReceiptVerificationJob).to receive(:perform_later).with(receipt.id, force: true)
        post reprocess_dashboard_business_receipt_path(business, receipt)
      end

      it "redirige al detalle del comprobante" do
        post reprocess_dashboard_business_receipt_path(business, receipt)
        expect(response).to redirect_to(dashboard_business_receipt_path(business, receipt))
      end
    end

    context "con formato Turbo Stream" do
      it "devuelve 200 con content-type turbo-stream" do
        post reprocess_dashboard_business_receipt_path(business, receipt),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("turbo-stream")
      end
    end
  end
end
