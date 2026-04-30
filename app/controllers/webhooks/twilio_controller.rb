class Webhooks::TwilioController < ActionController::Base
  skip_forgery_protection

  HELP_MESSAGE = "Para enviar tu comprobante, escribe primero: *Comprobante para <nombre-del-negocio>* y luego adjunta la imagen."

  def receive
    body    = params[:Body].to_s.strip
    from    = params[:From].to_s
    num_media = params[:NumMedia].to_i

    business = resolve_business(body)

    if business.nil?
      reply(from, HELP_MESSAGE)
      return head :ok
    end

    if num_media == 0
      reply(from, "Recibimos tu mensaje para *#{business.name}* pero no encontramos ninguna imagen. Por favor adjunta la foto de tu comprobante.")
      return head :ok
    end

    media_url      = params[:MediaUrl0]
    media_type     = params[:MediaContentType0].to_s

    unless media_type.start_with?("image/", "application/pdf")
      reply(from, "Solo aceptamos imágenes o PDF como comprobante.")
      return head :ok
    end

    receipt = build_receipt(business, from, media_url, media_type)

    if receipt.nil?
      reply(from, "No pudimos descargar tu imagen. Intenta de nuevo en un momento.")
      return head :ok
    end

    if receipt.save
      WhatsappReplyJob.perform_later(from, "✅ Comprobante recibido para *#{business.name}*. Lo estamos verificando, te avisamos en un momento.")
    else
      reply(from, "Hubo un problema al guardar tu comprobante. Intenta de nuevo.")
    end

    head :ok
  end

  private

  # Extrae el slug del cuerpo del mensaje.
  # Acepta: "Comprobante para tacos-el-gordo" o simplemente "tacos-el-gordo"
  def resolve_business(body)
    slug = body.downcase
                .gsub(/comprobante\s+para\s+/i, "")
                .strip
                .gsub(/\s+/, "-")

    Business.find_by(slug: slug)
  end

  def build_receipt(business, from, media_url, media_type)
    file_data = download_media(media_url)
    return nil if file_data.nil? || file_data.empty?

    receipt = business.receipts.build(
      payer_phone:  from.gsub("whatsapp:", ""),
      submitted_at: Time.current
    )

    extension = media_type.include?("pdf") ? "pdf" : "jpg"

    receipt.file.attach(
      io:           StringIO.new(file_data),
      filename:     "whatsapp_receipt_#{Time.current.to_i}.#{extension}",
      content_type: media_type
    )

    receipt
  end

  def download_media(url, limit = 5)
    raise "Demasiados redirects" if limit == 0

    account_sid = ENV.fetch("TWILIO_ACCOUNT_SID")
    auth_token  = ENV.fetch("TWILIO_AUTH_TOKEN")

    uri = URI.parse(url)
    req = Net::HTTP::Get.new(uri)
    req.basic_auth(account_sid, auth_token)

    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      response = http.request(req)

      case response
      when Net::HTTPSuccess
        response.body
      when Net::HTTPRedirection
        download_media(response["location"], limit - 1)
      else
        Rails.logger.error("[TwilioWebhook] Error descargando media #{url}: #{response.code} #{response.body[0..200]}")
        nil
      end
    end
  end

  def reply(to, message)
    client = Twilio::REST::Client.new(
      ENV.fetch("TWILIO_ACCOUNT_SID"),
      ENV.fetch("TWILIO_AUTH_TOKEN")
    )

    client.messages.create(
      from: ENV.fetch("TWILIO_WHATSAPP_NUMBER"),
      to:   to,
      body: message
    )
  end
end
