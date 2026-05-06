require "rails_helper"

# Los specs de helpers prueban métodos que generan HTML para las vistas.
# type: :helper activa el contexto de vista — nos da acceso a content_tag,
# link_to y demás helpers de ActionView sin necesidad de un controlador real.
RSpec.describe ApplicationHelper, type: :helper do

  # ─── receipt_status_badge ────────────────────────────────────────────────────
  # Este helper genera un <span> con estilos distintos según el status del comprobante.
  # Probamos dos cosas por cada status:
  #   1. Que el texto (label) sea el correcto
  #   2. Que las clases CSS correspondan al color del estado
  describe "#receipt_status_badge" do

    context "cuando el status es 'verified'" do
      subject(:html) { helper.receipt_status_badge("verified") }

      it "muestra el label 'Verificado'" do
        # have_text verifica el contenido de texto del HTML generado
        expect(html).to have_text("Verificado")
      end

      it "aplica clases de color verde (emerald)" do
        expect(html).to include("text-emerald-400")
      end
    end

    context "cuando el status es 'rejected'" do
      subject(:html) { helper.receipt_status_badge("rejected") }

      it "muestra el label 'Rechazado'" do
        expect(html).to have_text("Rechazado")
      end

      it "aplica clases de color rojo" do
        expect(html).to include("text-red-400")
      end
    end

    context "cuando el status es 'unreadable'" do
      subject(:html) { helper.receipt_status_badge("unreadable") }

      it "muestra el label 'No legible'" do
        expect(html).to have_text("No legible")
      end

      it "aplica clases de color gris (slate)" do
        expect(html).to include("text-slate-400")
      end
    end

    context "cuando el status es 'pending' (o cualquier otro valor)" do
      subject(:html) { helper.receipt_status_badge("pending") }

      it "muestra el label 'Analizando…'" do
        expect(html).to have_text("Analizando…")
      end

      it "aplica clases de color amarillo (amber)" do
        expect(html).to include("text-amber-400")
      end
    end

    context "para cualquier status" do
      it "siempre genera un elemento <span>" do
        # Independientemente del status, el resultado debe ser un span
        %w[verified rejected unreadable pending].each do |status|
          html = helper.receipt_status_badge(status)
          expect(html).to have_selector("span")
        end
      end

      it "siempre incluye clases base de badge" do
        html = helper.receipt_status_badge("verified")
        expect(html).to include("inline-flex", "rounded-full", "ring-1")
      end
    end
  end
end
