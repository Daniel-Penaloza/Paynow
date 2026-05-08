require "rails_helper"

# Spec del controlador CRUD de negocios del dashboard.
# Cosas clave que probamos aquí:
#   1. Protección de autenticación: sin login → redirige al login
#   2. Autorización: un usuario no ve los negocios de otro
#   3. Respuestas HTTP correctas en cada acción (200, 302, 422)
RSpec.describe "Dashboard::Businesses", type: :request do
  # Creamos un usuario dueño con un negocio propio
  let(:user)     { create(:user) }
  let(:business) { create(:business, user: user) }

  # before :each — se ejecuta antes de cada ejemplo de este bloque principal
  before { sign_in(user) }

  # ─── Protección de autenticación ─────────────────────────────────────────────
  # Verificamos que sin sesión activa el controlador redirige al login.
  # Aquí NO llamamos sign_in, así que no hay sesión.
  describe "cuando el usuario NO está autenticado" do
    # Sobreescribimos el before del bloque padre para NO hacer sign_in
    before { delete session_path } # cerrar sesión si estaba abierta

    it "redirige al login al intentar acceder al índice" do
      get dashboard_businesses_path
      expect(response).to redirect_to(new_session_path)
    end
  end

  # ─── GET /dashboard/businesses — índice ──────────────────────────────────────
  describe "GET /dashboard/businesses" do
    it "devuelve 200" do
      get dashboard_businesses_path
      expect(response).to have_http_status(:ok)
    end

    it "solo muestra los negocios del usuario actual" do
      # IMPORTANTE: como `business` es lazy (let), hay que referenciarlo ANTES del GET
      # para que exista en la base de datos cuando se renderice la vista.
      business
      otro_negocio = create(:business) # crea su propio usuario nuevo

      get dashboard_businesses_path

      # response.body contiene el HTML completo de la respuesta
      expect(response.body).to include(business.name)
      expect(response.body).not_to include(otro_negocio.name)
    end
  end

  # ─── GET /dashboard/businesses/new — formulario de creación ──────────────────
  describe "GET /dashboard/businesses/new" do
    it "devuelve 200" do
      get new_dashboard_business_path
      expect(response).to have_http_status(:ok)
    end
  end

  # ─── POST /dashboard/businesses — crear negocio ──────────────────────────────
  describe "POST /dashboard/businesses" do
    # Parámetros mínimos válidos para crear un negocio
    let(:params_validos) do
      {
        business: {
          name:         "Mi Taquería",
          clabe:        "012345678901234567",
          holder_name:  "Juan López",
          whatsapp:     "5512345678",
          instructions: "Solo SPEI"
        }
      }
    end

    context "con parámetros válidos" do
      it "crea el negocio y redirige al show" do
        # expect { }.to change verifica que el conteo cambia en 1
        expect {
          post dashboard_businesses_path, params: params_validos
        }.to change(Business, :count).by(1)

        # El negocio creado pertenece al usuario actual
        expect(response).to redirect_to(dashboard_business_path(Business.last))
      end
    end

    context "con parámetros inválidos (nombre vacío)" do
      it "devuelve 422 y re-renderiza el formulario" do
        params_invalidos = params_validos.deep_merge(business: { name: "" })

        expect {
          post dashboard_businesses_path, params: params_invalidos
        }.not_to change(Business, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "cuando la organización alcanzó el límite de negocios del plan" do
      it "redirige con alerta y no crea el negocio" do
        # El usuario ya tiene un negocio (plan free = límite 1)
        business

        expect {
          post dashboard_businesses_path, params: params_validos
        }.not_to change(Business, :count)

        expect(response).to redirect_to(new_dashboard_business_path)
        follow_redirect!
        expect(response.body).to include("límite de negocios")
      end
    end
  end

  # ─── GET /dashboard/businesses/:id — detalle ─────────────────────────────────
  describe "GET /dashboard/businesses/:id" do
    it "devuelve 200 para el propio negocio" do
      get dashboard_business_path(business)
      expect(response).to have_http_status(:ok)
    end

    it "devuelve 404 si el negocio no pertenece al usuario" do
      # En request specs las excepciones no se propagan — Rack las convierte a HTTP.
      # ActiveRecord::RecordNotFound → 404 Not Found automáticamente en Rails.
      negocio_ajeno = create(:business)
      get dashboard_business_path(negocio_ajeno)
      expect(response).to have_http_status(:not_found)
    end
  end

  # ─── PATCH /dashboard/businesses/:id — actualizar ────────────────────────────
  describe "PATCH /dashboard/businesses/:id" do
    context "con datos válidos" do
      it "actualiza el negocio y redirige al show" do
        patch dashboard_business_path(business), params: {
          business: { name: "Nombre Nuevo" }
        }
        expect(business.reload.name).to eq("Nombre Nuevo")
        expect(response).to redirect_to(dashboard_business_path(business))
      end
    end

    context "con datos inválidos" do
      it "devuelve 422" do
        patch dashboard_business_path(business), params: {
          business: { name: "" }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # ─── DELETE /dashboard/businesses/:id — eliminar ─────────────────────────────
  describe "DELETE /dashboard/businesses/:id" do
    it "elimina el negocio y redirige al índice" do
      business # referenciamos para que se cree antes del expect

      expect {
        delete dashboard_business_path(business)
      }.to change(Business, :count).by(-1)

      expect(response).to redirect_to(dashboard_businesses_path)
    end
  end

  # ─── GET /dashboard/businesses/:id/qr ────────────────────────────────────────
  describe "GET /dashboard/businesses/:id/qr" do
    it "devuelve 200" do
      get qr_dashboard_business_path(business)
      expect(response).to have_http_status(:ok)
    end
  end
end
