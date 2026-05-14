require "rails_helper"

# Verifica que los security headers estén presentes en las respuestas HTTP.
# Se prueban tanto rutas públicas (sin auth) como rutas protegidas (con auth).

RSpec.describe "Security headers", type: :request do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, organization: organization) }
  let(:business)     { create(:business, user: user) }

  shared_examples "respuesta con security headers" do
    it "incluye X-Frame-Options: DENY" do
      expect(response.headers["X-Frame-Options"]).to eq("DENY")
    end

    it "incluye X-Content-Type-Options: nosniff" do
      expect(response.headers["X-Content-Type-Options"]).to eq("nosniff")
    end

    it "incluye Content-Security-Policy" do
      expect(response.headers["Content-Security-Policy"]).to be_present
    end

    it "CSP incluye default-src 'self'" do
      expect(response.headers["Content-Security-Policy"]).to include("default-src 'self'")
    end

    it "CSP bloquea object-src" do
      expect(response.headers["Content-Security-Policy"]).to include("object-src 'none'")
    end

    it "CSP previene iframes con frame-ancestors 'none'" do
      expect(response.headers["Content-Security-Policy"]).to include("frame-ancestors 'none'")
    end

    it "CSP permite Google Fonts en style-src" do
      expect(response.headers["Content-Security-Policy"]).to include("https://fonts.googleapis.com")
    end

    it "CSP permite WebSockets en connect-src" do
      expect(response.headers["Content-Security-Policy"]).to include("connect-src")
      expect(response.headers["Content-Security-Policy"]).to include("wss:")
    end

    it "CSP incluye nonce en script-src (no usa unsafe-inline en scripts)" do
      csp = response.headers["Content-Security-Policy"]
      # Extraemos solo la directiva script-src para verificar que no tiene unsafe-inline
      script_src = csp.split(";").map(&:strip).find { |d| d.start_with?("script-src") }
      expect(script_src).to include("'nonce-")
      expect(script_src).not_to include("'unsafe-inline'")
    end
  end

  # ── Ruta pública (sin autenticación) ──────────────────────────────────────
  describe "GET /:slug — landing page pública" do
    before do
      host! "#{organization.subdomain}.lvh.me"
      get pay_path(business.slug)
    end

    include_examples "respuesta con security headers"
  end

  # ── Ruta protegida (con autenticación) ────────────────────────────────────
  describe "GET /dashboard — overview del negocio" do
    before do
      sign_in(user)
      get dashboard_root_path
    end

    include_examples "respuesta con security headers"
  end

  # ── Página de login ───────────────────────────────────────────────────────
  describe "GET /session/new — formulario de login" do
    before { get new_session_path }

    include_examples "respuesta con security headers"
  end
end
