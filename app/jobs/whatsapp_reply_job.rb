class WhatsappReplyJob < ApplicationJob
  queue_as :default

  def perform(to, message)
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
