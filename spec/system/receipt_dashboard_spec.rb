require "rails_helper"

# System spec del dashboard de comprobantes.
# Prueba la experiencia del dueño del negocio:
#   1. Inicia sesión con el formulario real
#   2. Ve la lista de comprobantes con sus badges de status
#   3. Verifica que la página incluye la suscripción Turbo Stream
#   4. Verifica que el total contable refleja solo los comprobantes verificados
#
# Driver: rack_test (sin JS)
# El comportamiento real-time de Turbo Streams está cubierto a nivel de job
# (ReceiptVerificationJob spec verifica que broadcast_update y
# broadcast_accounting_update son invocados con los argumentos correctos).
RSpec.describe "Dashboard de comprobantes", type: :system do

  let(:user)     { create(:user) }
  let(:business) { create(:business, user: user) }

  def sign_in_as(user)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password",      with: "password123"
    # El formulario tiene un <button> tab y un <input type="submit"> con el mismo texto.
    # Apuntamos al input de submit para evitar ambigüedad.
    find('input[type="submit"]').click
  end

  before { sign_in_as(user) }

  # ─── Lista de comprobantes ────────────────────────────────────────────────
  describe "lista de comprobantes" do

    it "muestra el badge 'Analizando…' para comprobantes en estado pending" do
      create(:receipt, business: business)
      visit dashboard_business_path(business)

      expect(page).to have_text("Analizando…")
    end

    it "muestra el badge 'Verificado' para comprobantes verificados" do
      create(:receipt, :verified, business: business)
      visit dashboard_business_path(business)

      expect(page).to have_text("Verificado")
    end

    it "muestra el badge 'Rechazado' para comprobantes rechazados" do
      create(:receipt, :rejected, business: business)
      visit dashboard_business_path(business)

      expect(page).to have_text("Rechazado")
    end

    it "muestra el monto formateado en comprobantes verificados" do
      create(:receipt, :verified, business: business, amount_cents: 150_000)
      visit dashboard_business_path(business)

      # number_with_delimiter muestra el separador de miles: "1,500"
      expect(page).to have_text("1,500")
    end

    it "no muestra comprobantes de otros negocios" do
      receipt_propio = create(:receipt, :verified, business: business)
      otro_negocio   = create(:business)
      receipt_ajeno  = create(:receipt, :verified, business: otro_negocio, payer_name: "Pagador Ajeno")

      visit dashboard_business_path(business)

      expect(page).not_to have_text(receipt_ajeno.payer_name)
    end
  end

  # ─── Suscripción Turbo Stream ─────────────────────────────────────────────
  describe "suscripción en tiempo real" do

    it "incluye el tag turbo-cable-stream-source para recibir actualizaciones en vivo" do
      visit dashboard_business_path(business)

      # turbo_stream_from renderiza <turbo-cable-stream-source channel="Turbo::StreamsChannel">.
      # El signed-stream-name es un token firmado (no contiene el nombre en texto plano),
      # así que verificamos la presencia del elemento y el canal correcto.
      expect(page.body).to include('channel="Turbo::StreamsChannel"')
    end
  end

  # ─── Contabilidad ─────────────────────────────────────────────────────────
  describe "totales contables" do

    it "suma solo los comprobantes verificados" do
      create(:receipt, :verified,  business: business, amount_cents: 20_000)
      create(:receipt, :verified,  business: business, amount_cents: 30_000)
      create(:receipt, :rejected,  business: business)
      create(:receipt,             business: business) # pending

      visit dashboard_business_path(business)

      # Total verificado: $200 + $300 = $500
      expect(page).to have_text("500")
    end

    it "muestra $0 cuando no hay comprobantes verificados" do
      create(:receipt, :rejected, business: business)
      visit dashboard_business_path(business)

      expect(page).to have_text("$0")
    end
  end

  # ─── Botón de reprocesar ──────────────────────────────────────────────────
  describe "reprocesar comprobante" do

    it "muestra el botón reprocesar en comprobantes rechazados" do
      create(:receipt, :rejected, business: business)
      visit dashboard_business_path(business)

      expect(page).to have_text("Reprocesar")
    end

    it "no muestra el botón reprocesar en comprobantes verificados" do
      create(:receipt, :verified, business: business)
      visit dashboard_business_path(business)

      expect(page).not_to have_text("Reprocesar")
    end
  end
end
