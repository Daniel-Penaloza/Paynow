require "rails_helper"

# Pruebas de rate limiting con Rack::Attack.
#
# Setup requerido en cada ejemplo:
#   - Se usa un MemoryStore limpio para aislar contadores entre tests.
#   - Se elimina el safelist "allow-all-in-dev" que bypass todo en test/dev.
#   - Se restaura el safelist al finalizar para no contaminar otros specs.
#
# Usamos host! con el subdominio de la organización para que el throttle de
# landing pages detecte has_subdomain = true, igual que en producción.

RSpec.describe "Rack::Attack throttling", type: :request do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, organization: organization) }
  let(:business)     { create(:business, user: user) }

  before do
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.safelists.delete("allow-all-in-dev")
    host! "#{organization.subdomain}.lvh.me"
  end

  after do
    Rack::Attack.reset!
    Rack::Attack.safelist("allow-all-in-dev") { true }
  end

  # ── 1. Flood de subida de comprobantes ─────────────────────────────────────
  describe "throttle: submit_receipt (POST /:slug/receipt)" do
    let(:ip_a) { "1.2.3.4" }
    let(:ip_b) { "9.8.7.6" }

    def post_receipt(ip)
      post submit_receipt_path(business.slug), env: { "REMOTE_ADDR" => ip }
    end

    it "permite los primeros 5 requests de la misma IP" do
      5.times { post_receipt(ip_a) }
      expect(response.status).not_to eq(429)
    end

    it "bloquea el 6to request con 429" do
      5.times { post_receipt(ip_a) }
      post_receipt(ip_a)
      expect(response).to have_http_status(429)
    end

    it "no bloquea a una IP diferente aunque otra ya esté throttleada" do
      6.times { post_receipt(ip_a) }
      post_receipt(ip_b)
      expect(response.status).not_to eq(429)
    end

    it "incluye el header Retry-After en la respuesta 429" do
      6.times { post_receipt(ip_a) }
      expect(response.headers["Retry-After"]).to eq("60")
    end
  end

  # ── 2. Scraping de landing pages de pago ───────────────────────────────────
  describe "throttle: landing pages (GET /:slug con subdominio)" do
    let(:ip_a) { "2.3.4.5" }
    let(:ip_b) { "6.7.8.9" }

    def get_landing(ip)
      get pay_path(business.slug), env: { "REMOTE_ADDR" => ip }
    end

    it "permite las primeras 30 visitas de la misma IP" do
      30.times { get_landing(ip_a) }
      expect(response.status).not_to eq(429)
    end

    it "bloquea la visita 31 con 429" do
      30.times { get_landing(ip_a) }
      get_landing(ip_a)
      expect(response).to have_http_status(429)
    end

    it "no bloquea a una IP diferente aunque otra ya esté throttleada" do
      31.times { get_landing(ip_a) }
      get_landing(ip_b)
      expect(response.status).not_to eq(429)
    end
  end

  # ── 3. Intentos de login ───────────────────────────────────────────────────
  describe "throttle: login (POST /session)" do
    let(:ip_a) { "3.4.5.6" }
    let(:ip_b) { "7.8.9.0" }

    def post_login(ip)
      post session_path,
           params: { email_address: "inexistente@test.com", password: "wrong" },
           env: { "REMOTE_ADDR" => ip }
    end

    it "permite los primeros 5 intentos de la misma IP" do
      5.times { post_login(ip_a) }
      expect(response.status).not_to eq(429)
    end

    it "bloquea el 6to intento con 429" do
      5.times { post_login(ip_a) }
      post_login(ip_a)
      expect(response).to have_http_status(429)
    end

    it "no bloquea a una IP diferente aunque otra ya esté throttleada" do
      6.times { post_login(ip_a) }
      post_login(ip_b)
      expect(response.status).not_to eq(429)
    end
  end
end
