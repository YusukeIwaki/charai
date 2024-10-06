# frozen_string_literal: true

require "charai"
require "sinatra/base"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.define_derived_metadata(file_path: %r(/spec/local/)) do |metadata|
    metadata[:type] = :local
  end
  config.define_derived_metadata(file_path: %r(/spec/web/)) do |metadata|
    metadata[:type] = :web
  end

  config.before(:each, type: :local) do
    @sinatra = Class.new(Sinatra::Base)

    Capybara.current_driver = :charai
    Capybara.javascript_driver = :charai
    Capybara.app = @sinatra
  end

  config.before(:each, type: :web) do
    Capybara.current_driver = :charai
    Capybara.javascript_driver = :charai
    Capybara.app = nil
  end

  driver_options = {
  }
  Capybara.register_driver :charai do |app|
    Charai::Driver.new(app, **driver_options)
  end
end
