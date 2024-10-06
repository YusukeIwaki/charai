# frozen_string_literal: true

module Charai
  class Driver < ::Capybara::Driver::Base
    def initialize(_app, **options)
    end

    def wait?; false; end
    def needs_server?; true; end

    def <<(text)
      browser
      puts text
    end

    def reset!
      @browser&.close
    end

    private

    def browser
      @browser ||= Browser.launch(headless: false)
    end
  end
end
