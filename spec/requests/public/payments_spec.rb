require "rails_helper"

# Spec del controlador público de pagos.
# Dos particularidades importantes:
#   1. No requiere autenticación (hereda de ActionController::Base)
#   2. Usa subdomain routing: la organización se resuelve desde request.subdomain
#      → en los specs usamos `host!` para simular el subdominio correcto
RSpec.describe "Public::Payments", type: :request do

  let(:organization) { create(:organization) }
  let(:user)         { create(:user, organization: organization) }
  let(:business)     { create(:business, user: user) }

  # host! cambia el Host header de todas las peticiones del bloque.
  # El formato lvh.me es el dominio local estándar para pruebas con subdominios.
  before { host! "#{organization.subdomain}.lvh.me" }

  # ─── GET /:slug — página de pago ─────────────────────────────────────────────
  describe "GET /:slug" do

    context "cuando la organización y el negocio existen" do
      it "devuelve 200" do
        get pay_path(business.slug)
        expect(response).to have_http_status(:ok)
      end

      it "muestra el nombre del negocio y la CLABE" do
        get pay_path(business.slug)
        expect(response.body).to include(business.name)
        expect(response.body).to include(business.clabe)
      end
    end

    context "cuando el subdominio no corresponde a ninguna organización" do
      before { host! "subdominio-falso.lvh.me" }

      it "devuelve 404" do
        get pay_path(business.slug)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "cuando el slug no corresponde a ningún negocio" do
      it "devuelve 404" do
        get pay_path("negocio-inexistente")
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ─── POST /:slug/receipt — enviar comprobante ─────────────────────────────────
  describe "POST /:slug/receipt" do

    # Silenciamos callbacks externos para no llamar a Claude ni a Twilio
    before do
      allow_any_instance_of(Receipt).to receive(:enqueue_verification)
      allow_any_instance_of(Receipt).to receive(:broadcast_to_dashboard)
      allow_any_instance_of(Receipt).to receive(:broadcast_remove_to)
    end

    # Simulamos un archivo adjunto usando Rack::Test::UploadedFile
    let(:archivo) do
      Rack::Test::UploadedFile.new(
        StringIO.new("fake image"),
        "image/jpeg",
        original_filename: "comprobante.jpg"
      )
    end

    let(:params_validos) do
      {
        payer_name:  "Ana García",
        payer_phone: "5598765432",
        file:        archivo
      }
    end

    context "con datos válidos" do
      it "crea el comprobante y redirige a la página de pago" do
        expect {
          post submit_receipt_path(business.slug), params: params_validos
        }.to change(Receipt, :count).by(1)

        expect(response).to redirect_to(pay_path(business.slug))
      end
    end

    context "con datos inválidos (teléfono con formato incorrecto)" do
      it "devuelve 422 y no crea el comprobante" do
        params_invalidos = params_validos.merge(payer_phone: "abc")

        expect {
          post submit_receipt_path(business.slug), params: params_invalidos
        }.not_to change(Receipt, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "cuando la organización alcanzó el límite mensual de comprobantes" do
      it "devuelve 422 con mensaje de límite y no crea el comprobante" do
        create_list(:receipt, 50, business: business, created_at: Date.current.beginning_of_month + 1.hour)

        expect {
          post submit_receipt_path(business.slug), params: params_validos
        }.not_to change(Receipt, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("límite mensual de comprobantes")
      end
    end
  end
end
