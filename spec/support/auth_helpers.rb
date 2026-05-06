module AuthHelpers
  # Inicia sesión enviando credenciales reales al endpoint de sesiones.
  # Esto prueba el flujo de autenticación completo (cookie firmada incluida).
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
