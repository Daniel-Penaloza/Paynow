Rails.application.configure do
  config.content_security_policy do |policy|
    # Por defecto solo se permite contenido del propio dominio
    policy.default_src :self

    # Fuentes tipográficas: propio dominio + Google Fonts (Inter)
    policy.font_src :self, "https://fonts.gstatic.com"

    # Imágenes: propio dominio, URLs data: (QR base64), blob: (Active Storage previews), HTTPS externo
    policy.img_src :self, :data, :blob, :https

    # Objetos (Flash, plugins): bloqueados completamente
    policy.object_src :none

    # Scripts: propio dominio. El nonce generado más abajo cubre los inline scripts de importmap.
    policy.script_src :self

    # Estilos: propio dominio + inline (Tailwind los requiere) + Google Fonts CDN
    policy.style_src :self, :unsafe_inline, "https://fonts.googleapis.com"

    # Conexiones JS (XHR, WebSockets): propio dominio + WSS para ActionCable/Turbo Streams
    policy.connect_src :self, :wss

    # Previene que la página sea embebida en iframes (refuerza X-Frame-Options: DENY)
    policy.frame_ancestors :none

    # Previene inyección de etiqueta <base> que podría redirigir recursos relativos
    policy.base_uri :self
  end

  # Genera un nonce aleatorio por request para los inline scripts de importmap.
  # Esto permite script-src 'self' sin necesitar 'unsafe-inline'.
  # SecureRandom funciona en rutas públicas que no tienen sesión activa.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
