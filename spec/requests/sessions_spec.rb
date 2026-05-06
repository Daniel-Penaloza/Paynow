require "rails_helper"

# Los request specs prueban la pila completa: routing → controlador → respuesta HTTP.
# Son el tipo de spec preferido en Rails moderno (sustituyen a controller specs).
# Aquí verificamos el flujo de autenticación: login, logout, redirecciones.
RSpec.describe "Sessions", type: :request do

  let(:user) { create(:user) }

  # ─── GET /session/new — formulario de login ──────────────────────────────────
  describe "GET /session/new" do

    context "cuando el usuario NO está autenticado" do
      it "devuelve 200 y muestra el formulario" do
        get new_session_path
        # have_http_status verifica el código de respuesta HTTP
        expect(response).to have_http_status(:ok)
      end
    end

    context "cuando el usuario YA está autenticado" do
      before { sign_in(user) }

      it "redirige al dashboard (no muestra el login de nuevo)" do
        get new_session_path
        # redirect_to verifica el destino de la redirección
        expect(response).to redirect_to(dashboard_root_path)
      end
    end
  end

  # ─── POST /session — crear sesión (login) ────────────────────────────────────
  describe "POST /session" do

    context "con credenciales válidas" do
      it "redirige al dashboard" do
        post session_path, params: { email_address: user.email_address, password: "password123" }
        expect(response).to redirect_to(dashboard_root_path)
      end

      it "establece la cookie de sesión" do
        post session_path, params: { email_address: user.email_address, password: "password123" }
        # La cookie session_id es firmada (signed) — Rails la maneja automáticamente
        expect(response.cookies["session_id"]).to be_present
      end
    end

    context "con credenciales inválidas" do
      it "redirige de vuelta al login con alerta" do
        post session_path, params: { email_address: user.email_address, password: "wrong_password" }
        expect(response).to redirect_to(new_session_path)
      end

      # follow_redirect! sigue la redirección para inspeccionar el HTML final
      it "muestra mensaje de error en la página de login" do
        post session_path, params: { email_address: user.email_address, password: "wrong_password" }
        follow_redirect!
        expect(response.body).to include("Try another email address or password")
      end
    end
  end

  # ─── DELETE /session — cerrar sesión (logout) ────────────────────────────────
  describe "DELETE /session" do

    before { sign_in(user) }

    it "redirige al formulario de login" do
      delete session_path
      expect(response).to redirect_to(new_session_path)
    end

    it "elimina la cookie de sesión" do
      delete session_path
      # Una cookie eliminada queda con valor nil o vacío en la respuesta
      expect(response.cookies["session_id"]).to be_nil
    end
  end
end
