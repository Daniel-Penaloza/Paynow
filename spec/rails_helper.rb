require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'

# Carga automáticamente todos los archivos en spec/support/
Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  # Usa transacciones para limpiar la BD entre cada prueba (rápido y suficiente)
  config.use_transactional_fixtures = true

  # Infiere el tipo de spec según la carpeta (spec/models → type: :model, etc.)
  config.infer_spec_type_from_file_location!

  # Filtra líneas de gems de Rails en los backtraces para que sean más legibles
  config.filter_rails_from_backtrace!

  # Incluye helpers de FactoryBot sin necesidad de escribir FactoryBot.create(...)
  config.include FactoryBot::Syntax::Methods
end

# Configura shoulda-matchers para que funcione con RSpec + Rails
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
