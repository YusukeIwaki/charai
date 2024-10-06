# frozen_string_literal: true

module Charai
  class Driver < ::Capybara::Driver::Base
    def initialize(_app, **options)
      @headless = options[:headless]
      @debug_protocol = %w[1 true].include?(ENV['DEBUG'])
    end

    def wait?; false; end
    def needs_server?; true; end

    def <<(text)
      puts text
    end

    def reset!
      @browsing_context&.close
      @browsing_context = nil
    end

    def visit(path)
      host = Capybara.app_host || Capybara.default_host

      url =
        if host
          Addressable::URI.parse(host) + path
        else
          path
        end

      browsing_context.navigate(url)
    end

    private

    def browser
      @browser ||= Browser.launch(headless: @headless, debug_protocol: @debug_protocol)
    end

    def browsing_context
      @browsing_context ||= browser.create_browsing_context
    end
  end
end
