require "capybara/rspec"

# ─── Driver por defecto ───────────────────────────────────────────────────────
# rack_test: rápido, sin JS, sin navegador real. Suficiente para la mayoría
# de flujos de formulario.
# Para specs que necesitan JS (etiqueta `js: true`) se usa selenium headless.
RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, :js, type: :system) do
    driven_by :selenium_chrome_headless
  end

  # Restablece el host virtual de Capybara tras cada ejemplo para no contaminar
  # otros specs con la configuración de subdomain.
  config.after(:each, type: :system) do
    Capybara.app_host = nil
  end
end
