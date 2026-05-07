require "rails_helper"

# Los specs de jobs prueban la lógica de negocio del background job.
# La regla de oro: nunca llamar APIs externas reales en pruebas.
# Usamos "double" y "allow" para reemplazar llamadas externas con respuestas controladas.
RSpec.describe ReceiptVerificationJob, type: :job do

  # ─── Helpers compartidos ─────────────────────────────────────────────────────

  # subject es la instancia del job que usaremos en todos los ejemplos
  subject(:job) { described_class.new }

  # let crea objetos reutilizables en cada ejemplo de forma lazy (solo cuando se usan)
  let(:business) { create(:business) }
  let(:receipt)  { create(:receipt, business: business) }

  # before se ejecuta antes de cada ejemplo del bloque que lo contiene.
  # Aquí silenciamos todos los efectos secundarios externos del job:
  #   - Claude API → stub con una respuesta de "transferencia válida" por defecto
  #   - Turbo broadcasts → no transmitir nada real en pruebas
  #   - WhatsappReplyJob → solo verificamos que se encola, no que se ejecute
  before do
    # Stub de Claude: simula una respuesta exitosa de transferencia verificada
    allow(job).to receive(:call_claude).and_return({
      "is_transfer"      => true,
      "transfer_date"    => Date.current.to_s,
      "amount"           => 500.0,
      "bank_name"        => "BBVA",
      "reference_number" => "REF123456",
      "notes"            => nil
    })

    # Stub de broadcasts: evita que el job intente usar ActionCable/Turbo
    allow(job).to receive(:broadcast_update)
    allow(job).to receive(:broadcast_accounting_update)

    # Stub de WhatsApp: evita encolar jobs reales de Twilio
    allow(WhatsappReplyJob).to receive(:perform_later)
  end

  # ─── perform: flujo principal ────────────────────────────────────────────────
  describe "#perform" do

    context "cuando el receipt no existe" do
      it "termina sin error" do
        # Pasamos un ID que no existe — el job debe ignorarlo silenciosamente
        expect { job.perform(0) }.not_to raise_error
      end
    end

    context "cuando el receipt no tiene archivo adjunto" do
      it "termina sin procesar" do
        # Creamos un receipt y desvinculamos su archivo para simular este caso
        receipt.file.detach
        expect { job.perform(receipt.id) }.not_to raise_error
        # El status no debe cambiar (el job salió antes de procesarlo)
        expect(receipt.reload.verification_status).to eq("pending")
      end
    end

    context "cuando prepare_image falla y devuelve nil" do
      before do
        # Forzamos que prepare_image devuelva nil (archivo corrupto, PDF sin ImageMagick, etc.)
        allow(job).to receive(:prepare_image).and_return(nil)
      end

      it "marca el receipt como 'unreadable'" do
        job.perform(receipt.id)
        expect(receipt.reload.verification_status).to eq("unreadable")
      end

      it "registra una nota de error en el receipt" do
        job.perform(receipt.id)
        expect(receipt.reload.verification_notes).to include("No se pudo procesar")
      end
    end

    context "cuando ocurre una excepción inesperada" do
      before do
        # Forzamos que call_claude lance una excepción (timeout, error de red, etc.)
        allow(job).to receive(:call_claude).and_raise(StandardError, "timeout")
      end

      it "marca el receipt como 'unreadable' en lugar de dejar caer el job" do
        job.perform(receipt.id)
        expect(receipt.reload.verification_status).to eq("unreadable")
      end
    end

    context "en el flujo normal exitoso" do
      it "llama a Claude con los datos de imagen" do
        # expect(...).to receive verifica que el método SÍ fue llamado
        expect(job).to receive(:call_claude)
        job.perform(receipt.id)
      end

      it "emite un broadcast de actualización al dashboard" do
        expect(job).to receive(:broadcast_update)
        job.perform(receipt.id)
      end

      it "emite un broadcast de actualización contable" do
        expect(job).to receive(:broadcast_accounting_update)
        job.perform(receipt.id)
      end
    end
  end

  # ─── apply_result: lógica de verificación ───────────────────────────────────
  # apply_result es privado, lo probamos a través de perform controlando
  # lo que devuelve call_claude (el stub del before de arriba)
  describe "lógica de verificación (apply_result)" do

    context "cuando Claude devuelve nil (respuesta inválida o no parseada)" do
      before { allow(job).to receive(:call_claude).and_return(nil) }

      it "marca el receipt como 'unreadable'" do
        job.perform(receipt.id)
        expect(receipt.reload.verification_status).to eq("unreadable")
      end
    end

    context "cuando la imagen no es una transferencia bancaria" do
      before do
        allow(job).to receive(:call_claude).and_return({
          "is_transfer" => false,
          "notes"       => "La imagen es una foto de una pizza, no un comprobante."
        })
      end

      it "marca el receipt como 'rejected'" do
        job.perform(receipt.id)
        expect(receipt.reload.verification_status).to eq("rejected")
      end

      it "guarda el motivo de rechazo en verification_notes" do
        job.perform(receipt.id)
        expect(receipt.reload.verification_notes).to include("pizza")
      end
    end

    context "cuando la transferencia es de una fecha diferente a hoy" do
      let(:fecha_pasada) { 3.days.ago.to_date }

      before do
        allow(job).to receive(:call_claude).and_return({
          "is_transfer"   => true,
          "transfer_date" => fecha_pasada.to_s,
          "amount"        => 200.0,
          "bank_name"     => "Nu",
          "notes"         => nil
        })
      end

      it "marca el receipt como 'rejected' (sin force)" do
        job.perform(receipt.id)
        expect(receipt.reload.verification_status).to eq("rejected")
      end

      it "menciona la fecha en el mensaje de rechazo" do
        job.perform(receipt.id)
        expect(receipt.reload.verification_notes).to include(fecha_pasada.strftime("%d/%m/%Y"))
      end

      it "lo verifica si se usa force: true" do
        # force: true permite aprobar comprobantes de días anteriores (modo reprocesado)
        job.perform(receipt.id, force: true)
        expect(receipt.reload.verification_status).to eq("verified")
      end
    end

    context "cuando la transferencia es válida y de hoy" do
      # El stub del before principal ya devuelve una transferencia válida de hoy

      it "marca el receipt como 'verified'" do
        job.perform(receipt.id)
        expect(receipt.reload.verification_status).to eq("verified")
      end

      it "guarda el monto en centavos" do
        # Claude devuelve 500.0 → 50_000 centavos
        job.perform(receipt.id)
        expect(receipt.reload.amount_cents).to eq(50_000)
      end

      it "guarda el nombre del banco" do
        job.perform(receipt.id)
        expect(receipt.reload.bank_name).to eq("BBVA")
      end

      it "guarda el número de referencia" do
        job.perform(receipt.id)
        expect(receipt.reload.reference_number).to eq("REF123456")
      end
    end
  end

  # ─── notify_payer: notificaciones WhatsApp ───────────────────────────────────
  # Aislamos notify_payer stubeando notify_owner para que las aserciones
  # solo cuenten las llamadas dirigidas al pagador, no al dueño del negocio.
  describe "notificaciones WhatsApp (notify_payer)" do

    before { allow(job).to receive(:notify_owner) }

    context "cuando el pagador no tiene teléfono registrado" do
      let(:receipt) { create(:receipt, business: business, payer_phone: "") }

      it "no encola ningún mensaje al pagador" do
        job.perform(receipt.id)
        expect(WhatsappReplyJob).not_to have_received(:perform_later)
      end
    end

    context "cuando el comprobante queda verificado" do
      it "encola un mensaje de WhatsApp al pagador" do
        job.perform(receipt.id)
        expect(WhatsappReplyJob).to have_received(:perform_later).once
      end

      it "el mensaje incluye el monto y el nombre del negocio" do
        job.perform(receipt.id)
        expect(WhatsappReplyJob).to have_received(:perform_later).with(
          anything,
          include("500.00", business.name)
        )
      end
    end

    context "cuando el comprobante es rechazado" do
      before do
        allow(job).to receive(:call_claude).and_return({
          "is_transfer" => false,
          "notes"       => "No es un comprobante válido."
        })
      end

      it "encola un mensaje de rechazo al pagador" do
        job.perform(receipt.id)
        expect(WhatsappReplyJob).to have_received(:perform_later).with(
          anything,
          include("❌")
        )
      end
    end

    context "cuando el comprobante es ilegible" do
      before { allow(job).to receive(:call_claude).and_return(nil) }

      it "encola un mensaje de imagen poco clara al pagador" do
        job.perform(receipt.id)
        expect(WhatsappReplyJob).to have_received(:perform_later).with(
          anything,
          include("⚠️")
        )
      end
    end
  end
end
