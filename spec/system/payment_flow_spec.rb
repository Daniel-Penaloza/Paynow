require "rails_helper"

# System spec del flujo público de pago.
# Prueba la experiencia completa del cliente que llega por QR:
#   1. Ve el nombre del negocio y la CLABE en la landing page
#   2. Sube un comprobante mediante el formulario
#   3. Recibe confirmación de envío
#   4. El Receipt queda registrado como pending en la BD
#
# Driver: rack_test (sin JS, suficiente para el formulario de subida)
# Subdomain: se simula via Capybara.app_host = "http://org.lvh.me"
RSpec.describe "Flujo de pago público", type: :system do

  let(:organization) { create(:organization) }
  let(:user)         { create(:user, organization: organization) }
  let(:business)     { create(:business, user: user) }

  # lvh.me resuelve a 127.0.0.1, lo que permite subdominios en local/CI
  before do
    Capybara.app_host = "http://#{organization.subdomain}.lvh.me"
  end

  # ─── Landing page de pago ─────────────────────────────────────────────────
  describe "landing page" do

    it "muestra el nombre del negocio y la CLABE" do
      visit pay_path(business.slug)

      expect(page).to have_text(business.name)
      expect(page).to have_text(business.clabe)
    end

    it "muestra el nombre del titular" do
      visit pay_path(business.slug)

      expect(page).to have_text(business.holder_name)
    end

    it "tiene el botón de copiar CLABE" do
      visit pay_path(business.slug)

      expect(page).to have_button("Copiar CLABE")
    end

    it "tiene el formulario de subida de comprobante" do
      visit pay_path(business.slug)

      expect(page).to have_button("Enviar comprobante")
    end
  end

  # ─── Subida de comprobante ────────────────────────────────────────────────
  describe "subir comprobante" do

    let(:fixture_path) { Rails.root.join("spec/fixtures/files/sample_receipt.jpg") }

    context "con archivo adjunto" do
      it "redirige de vuelta con mensaje de éxito" do
        visit pay_path(business.slug)

        # make_visible: true fuerza visible el input file oculto (sr-only en la vista)
        attach_file "file", fixture_path, make_visible: true
        click_button "Enviar comprobante"

        expect(page).to have_text("Comprobante enviado correctamente")
      end

      it "crea un Receipt en la base de datos" do
        visit pay_path(business.slug)

        attach_file "file", fixture_path, make_visible: true

        expect {
          click_button "Enviar comprobante"
        }.to change(Receipt, :count).by(1)
      end

      it "el receipt queda en estado pending" do
        visit pay_path(business.slug)

        attach_file "file", fixture_path, make_visible: true
        click_button "Enviar comprobante"

        expect(Receipt.last.verification_status).to eq("pending")
      end

      it "asocia el receipt al negocio correcto" do
        visit pay_path(business.slug)

        attach_file "file", fixture_path, make_visible: true
        click_button "Enviar comprobante"

        expect(Receipt.last.business).to eq(business)
      end
    end

    context "con datos del pagador opcionales" do
      it "guarda el nombre y teléfono del pagador si se proporcionan" do
        visit pay_path(business.slug)

        attach_file "file", fixture_path, make_visible: true

        # Los campos del pagador están ocultos tras un accordion — rellenamos por nombre
        fill_in "payer_name",  with: "Juan García"
        fill_in "payer_phone", with: "5512345678"
        click_button "Enviar comprobante"

        receipt = Receipt.last
        expect(receipt.payer_name).to eq("Juan García")
        expect(receipt.payer_phone).to eq("5512345678")
      end
    end
  end

  # ─── Organización inexistente ─────────────────────────────────────────────
  describe "cuando el subdomain no corresponde a ninguna organización" do
    before { Capybara.app_host = "http://subdominio-falso.lvh.me" }

    it "muestra error 404" do
      visit pay_path(business.slug)
      expect(page).to have_text("Organización no encontrada")
    end
  end
end
