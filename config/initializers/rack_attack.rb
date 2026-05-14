class Rack::Attack
  # En desarrollo y test no aplicar throttling
  if Rails.env.development? || Rails.env.test?
    safelist("allow-all-in-dev") { true }
  end

  # ── Flood de subida de comprobantes ──────────────────────────────────────────
  # Máximo 5 intentos de subir comprobante por IP cada 60 segundos.
  # Ruta real: POST /:slug/receipt  (o /dev/pay/:org/:slug/receipt en dev)
  # Mitiga bots que intenten saturar el negocio con comprobantes falsos.
  throttle("submit_receipt/ip", limit: 5, period: 60) do |req|
    req.ip if req.post? && req.path.end_with?("/receipt")
  end

  # ── Carga de landing pages públicas ──────────────────────────────────────────
  # Máximo 30 visitas a páginas de pago por IP cada 60 segundos.
  # Cubre: subdominios en producción (org.paynow.mx/:slug)
  #        y rutas /dev/pay/:org/:slug en desarrollo/test.
  # Mitiga scraping de CLABEs y datos de negocios.
  throttle("payments/ip", limit: 30, period: 60) do |req|
    is_dev_pay = req.path.include?("/pay/")
    has_subdomain = req.host.split(".").length > 2
    req.ip if req.get? && (is_dev_pay || has_subdomain)
  end

  # ── Intentos de login ─────────────────────────────────────────────────────────
  # Máximo 5 intentos de login por IP cada 20 segundos.
  throttle("sessions/ip", limit: 5, period: 20) do |req|
    req.ip if req.post? && req.path == "/session"
  end

  # ── Respuesta al ser bloqueado ────────────────────────────────────────────────
  self.throttled_responder = lambda do |env|
    [
      429,
      { "Content-Type" => "text/plain", "Retry-After" => "60" },
      [ "Demasiadas solicitudes. Intenta de nuevo en un momento." ]
    ]
  end
end
