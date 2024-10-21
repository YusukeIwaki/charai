# frozen_string_literal: true

require "charai"
require "sinatra/base"
require "allure-rspec"
require 'capybara/dsl'

class HtmlReport
  def initialize
    @content = []
  end

  def start(introduction)
    @content << <<~HTML
    <html>
    <head><link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/mini.css/3.0.1/mini-default.min.css"></head>
    <body>
    <pre style="margin: 100px 75px; border-left: 0px;">#{introduction}</pre>
    HTML
  end

  def add_conversation(content, answer)
    if content.is_a?(Array)
      text = content.find { |c| c[:type] == 'text' }[:text]

      @content << <<~HTML
      <div style="margin: 40px 25px" class="card fluid">
      <h4 style="border-left: .25rem solid var(--pre-color);">user</h4>
      <pre>#{text}</pre>
      HTML

      content.each do |c|
        next unless c[:type] == 'image_url'

        @content << <<~HTML
        <img src="#{c[:image_url][:url]}" width="480" />
        HTML
      end

      @content << <<~HTML
      <h4 style="text-align: end; border-right: .25rem solid var(--pre-color);">assistant</h4>
      <pre style="border-left: 0px; border-right: .25rem solid var(--pre-color);">#{answer}</pre>
      </div>
      HTML
    else
      @content << <<~HTML
      <div style="margin: 40px 25px" class="card fluid">
      <h4 style="border-left: .25rem solid var(--pre-color);">user</h4>
      <pre>#{content}</pre>

      <h4 style="text-align: end; border-right: .25rem solid var(--pre-color);">assistant</h4>
      <pre style="border-left: 0px; border-right: .25rem solid var(--pre-color);">#{answer}</pre>
      </div>
      HTML
    end
  end

  def to_html
    @content << "</body></html>"
    @content.join("\n")
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.order = :random

  Kernel.srand config.seed

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.define_derived_metadata(file_path: %r(/spec/local/)) do |metadata|
    metadata[:type] = :local
  end
  config.define_derived_metadata(file_path: %r(/spec/web/)) do |metadata|
    metadata[:type] = :web
  end

  config.formatter = AllureRspecFormatter

  config.before(:each, type: :local) do
    @sinatra = Class.new(Sinatra::Base)

    Capybara.current_driver = :charai_headless
    Capybara.javascript_driver = :charai
    Capybara.app = @sinatra
  end

  config.around(:each, type: :web) do |example|
    Capybara.current_driver = :charai
    Capybara.javascript_driver = :charai
    Capybara.app = nil

    report = HtmlReport.new
    Capybara.current_session.driver.callback = {
      on_chat_start: -> (introduction) {
        report.start(introduction)
      },
      on_chat_conversation: ->(content_hash, answer) {
        puts answer
        report.add_conversation(content_hash, answer)
      },
    }
    example.run

    Allure.add_attachment(
      name: "Chat Report",
      source: report.to_html,
      type: 'text/html',
    )

    Capybara.reset_sessions!
  end
  config.include(Capybara::DSL, type: :web)

  Capybara.register_driver :charai do |app|
    Charai::Driver.new(app)
  end
  Capybara.register_driver :charai_headless do |app|
    Charai::Driver.new(app, headless: true)
  end
end
