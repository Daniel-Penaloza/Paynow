require "rails_helper"

# Spec del webhook de Twilio (POST /webhooks/twilio).
# El controller hereda de ActionController::Base — sin autenticación de sesión.
# Dependencias externas que stubeamos:
#   - Twilio::REST::Client#messages#create  → evitar llamadas reales de WhatsApp
#   - Net::HTTP (download_media)            → evitar HTTP al descargar el archivo adjunto
RSpec.describe "Webhooks::Twilio", type: :request do
  let(:business) { create(:business) }

  # Helpers para stubar las dos dependencias de red ─────────────────────────────

  # Stubar el método privado `reply` para evitar llamadas reales a la API de Twilio.
  # Usamos allow_any_instance_of porque el controller lo instancia internamente.
  def stub_twilio_reply
    allow_any_instance_of(Webhooks::TwilioController)
      .to receive(:reply)
  end

  # Stubar download_media para devolver bytes de imagen falsos
  def stub_media_download(content: "fake image bytes")
    allow_any_instance_of(Webhooks::TwilioController)
      .to receive(:download_media).and_return(content)
  end

  # Parámetros base de un mensaje de WhatsApp entrante
  def twilio_params(overrides = {})
    {
      From:      "whatsapp:+525512345678",
      Body:      business.slug,
      NumMedia:  "0",
      MediaUrl0: nil,
      MediaContentType0: nil
    }.merge(overrides)
  end

  # ─── Cuerpo vacío — sin negocio identificable ─────────────────────────────────
  describe "mensaje sin cuerpo (Body vacío)" do
    before { stub_twilio_reply }

    it "responde 200 y envía instrucciones de uso" do
      post webhooks_twilio_path, params: twilio_params(Body: "")
      expect(response).to have_http_status(:ok)
    end
  end

  # ─── Negocio no encontrado ────────────────────────────────────────────────────
  describe "cuando el Body no corresponde a ningún negocio" do
    before { stub_twilio_reply }

    it "responde 200 con mensaje de negocio no encontrado" do
      post webhooks_twilio_path, params: twilio_params(Body: "negocio-inexistente-xyz")
      expect(response).to have_http_status(:ok)
    end
  end

  # ─── Negocio encontrado pero sin media adjunta ────────────────────────────────
  describe "cuando el negocio existe pero NumMedia es 0" do
    before { stub_twilio_reply }

    it "responde 200 y pide que adjunten imagen" do
      post webhooks_twilio_path, params: twilio_params(Body: business.slug, NumMedia: "0")
      expect(response).to have_http_status(:ok)
    end
  end

  # ─── Media adjunta con tipo no permitido ─────────────────────────────────────
  describe "cuando el adjunto no es imagen ni PDF" do
    before { stub_twilio_reply }

    it "responde 200 e indica que el tipo de archivo no es válido" do
      post webhooks_twilio_path, params: twilio_params(
        Body:              business.slug,
        NumMedia:          "1",
        MediaUrl0:         "https://api.twilio.com/media/fake",
        MediaContentType0: "text/plain"
      )
      expect(response).to have_http_status(:ok)
    end
  end

  # ─── Error al descargar la imagen ────────────────────────────────────────────
  describe "cuando download_media devuelve nil (falla de red)" do
    before do
      stub_twilio_reply
      stub_media_download(content: nil)
    end

    it "responde 200 con mensaje de error al recibir imagen" do
      post webhooks_twilio_path, params: twilio_params(
        Body:              business.slug,
        NumMedia:          "1",
        MediaUrl0:         "https://api.twilio.com/media/fake",
        MediaContentType0: "image/jpeg"
      )
      expect(response).to have_http_status(:ok)
    end
  end

  # ─── Flujo exitoso — imagen válida ───────────────────────────────────────────
  describe "cuando el negocio existe, hay imagen adjunta y la descarga es exitosa" do
    before do
      stub_media_download
      # WhatsappReplyJob se encola en background — no queremos ejecución real
      allow(WhatsappReplyJob).to receive(:perform_later)
    end

    it "responde 200 y crea un Receipt en estado pending" do
      expect {
        post webhooks_twilio_path, params: twilio_params(
          Body:              business.slug,
          NumMedia:          "1",
          MediaUrl0:         "https://api.twilio.com/media/fake",
          MediaContentType0: "image/jpeg"
        )
      }.to change(Receipt, :count).by(1)

      expect(response).to have_http_status(:ok)
    end

    it "asigna el teléfono del pagador al receipt" do
      post webhooks_twilio_path, params: twilio_params(
        Body:              business.slug,
        NumMedia:          "1",
        MediaUrl0:         "https://api.twilio.com/media/fake",
        MediaContentType0: "image/jpeg"
      )

      receipt = Receipt.last
      # El controller elimina el prefijo "whatsapp:" antes de guardar
      expect(receipt.payer_phone).to eq("+525512345678")
    end

    it "encola WhatsappReplyJob con confirmación de recepción" do
      post webhooks_twilio_path, params: twilio_params(
        Body:              business.slug,
        NumMedia:          "1",
        MediaUrl0:         "https://api.twilio.com/media/fake",
        MediaContentType0: "image/jpeg"
      )

      expect(WhatsappReplyJob).to have_received(:perform_later)
        .with("whatsapp:+525512345678", a_string_including(business.name))
    end

    it "acepta PDFs además de imágenes" do
      expect {
        post webhooks_twilio_path, params: twilio_params(
          Body:              business.slug,
          NumMedia:          "1",
          MediaUrl0:         "https://api.twilio.com/media/fake.pdf",
          MediaContentType0: "application/pdf"
        )
      }.to change(Receipt, :count).by(1)
    end

    it "resuelve el negocio por nombre con tildes (normalización unicode)" do
      business.update!(slug: "tacos-el-guero")

      expect {
        post webhooks_twilio_path, params: twilio_params(
          Body:              "Comprobante para Tacos El Güero",
          NumMedia:          "1",
          MediaUrl0:         "https://api.twilio.com/media/fake",
          MediaContentType0: "image/jpeg"
        )
      }.to change(Receipt, :count).by(1)
    end
  end
end
