class ReceiptVerificationJob < ApplicationJob
  queue_as :default

  PROMPT = <<~PROMPT
    Analiza esta imagen y determina si es un comprobante de transferencia bancaria.

    Responde ÚNICAMENTE con un objeto JSON válido con esta estructura exacta, sin texto adicional:
    {
      "is_transfer": true o false,
      "transfer_date": "YYYY-MM-DD" o null,
      "amount": número decimal o null,
      "bank_name": "nombre del banco" o null,
      "reference_number": "número de referencia/folio" o null,
      "notes": "razón si no es transferencia o si hay algún problema" o null
    }

    Reglas:
    - is_transfer: true solo si es claramente un comprobante de transferencia bancaria o SPEI
    - transfer_date: la fecha en que se realizó la transferencia (no la fecha de captura)
    - amount: el monto transferido como número (sin símbolos, solo dígitos y punto decimal)
    - bank_name: el banco o neobanco emisor (BBVA, Nu, Santander, Banorte, Mercado Pago, etc.)
    - reference_number: folio, número de rastreo SPEI o referencia del comprobante
    - notes: solo si is_transfer es false o si no puedes leer algún campo importante
  PROMPT

  def perform(receipt_id)
    receipt = Receipt.find_by(id: receipt_id)
    return unless receipt&.file&.attached?

    image_data = prepare_image(receipt)
    unless image_data
      receipt.update!(verification_status: "unreadable", verification_notes: "No se pudo procesar el archivo adjunto.")
      broadcast_update(receipt)
      return
    end

    result = call_claude(image_data)
    apply_result(receipt, result)
    broadcast_update(receipt)
  rescue => e
    Rails.logger.error("[ReceiptVerificationJob] Error en receipt #{receipt_id}: #{e.message}")
    receipt&.update!(verification_status: "unreadable", verification_notes: "Error interno al procesar el comprobante.")
    broadcast_update(receipt) if receipt
  end

  private

  def prepare_image(receipt)
    content_type = receipt.file.content_type

    if content_type == "application/pdf"
      convert_pdf_to_image(receipt)
    elsif content_type&.start_with?("image/")
      {
        data: Base64.strict_encode64(receipt.file.download),
        media_type: content_type
      }
    end
  end

  def convert_pdf_to_image(receipt)
    receipt.file.open do |file|
      image = MiniMagick::Image.open(file.path)
      image.format("png")
      png_data = File.binread(image.path)
      { data: Base64.strict_encode64(png_data), media_type: "image/png" }
    end
  rescue => e
    Rails.logger.error("[ReceiptVerificationJob] Error convirtiendo PDF: #{e.message}")
    nil
  end

  def call_claude(image_data)
    client = Anthropic::Client.new(access_token: ENV.fetch("ANTHROPIC_API_KEY"))

    response = client.messages(parameters: {
      model: "claude-haiku-4-5-20251001",
      max_tokens: 512,
      messages: [
        {
          role: "user",
          content: [
            {
              type: "image",
              source: {
                type: "base64",
                media_type: image_data[:media_type],
                data: image_data[:data]
              }
            },
            { type: "text", text: PROMPT }
          ]
        }
      ]
    })

    raw = response.dig("content", 0, "text") || ""
    raw = raw.gsub(/\A```(?:json)?\s*|\s*```\z/, "").strip
    JSON.parse(raw)
  rescue JSON::ParserError => e
    Rails.logger.error("[ReceiptVerificationJob] JSON inválido de Claude: #{e.message}")
    nil
  end

  def apply_result(receipt, result)
    if result.nil?
      receipt.update!(verification_status: "unreadable", verification_notes: "No se pudo interpretar la respuesta del análisis.")
      return
    end

    unless result["is_transfer"]
      receipt.update!(
        verification_status: "rejected",
        verification_notes: result["notes"] || "La imagen no corresponde a un comprobante de transferencia bancaria."
      )
      return
    end

    transfer_date = result["transfer_date"] ? Date.parse(result["transfer_date"]) : nil

    if transfer_date && transfer_date != Date.current
      receipt.update!(
        verification_status: "rejected",
        transfer_date: transfer_date,
        bank_name: result["bank_name"],
        verification_notes: "El comprobante es de una fecha diferente a la de hoy (#{transfer_date.strftime('%d/%m/%Y')})."
      )
      return
    end

    receipt.update!(
      verification_status: "verified",
      transfer_date: transfer_date,
      amount_cents: result["amount"] ? (result["amount"].to_f * 100).round : nil,
      bank_name: result["bank_name"],
      reference_number: result["reference_number"],
      verification_notes: nil
    )
  end

  def broadcast_update(receipt)
    receipt.broadcast_replace_to(
      "business_#{receipt.business_id}_receipts",
      target: "receipt_#{receipt.id}",
      partial: "dashboard/receipts/receipt",
      locals: { receipt: receipt, business: receipt.business }
    )
  end
end
