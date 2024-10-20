require 'spec_helper'

RSpec.describe Charai::Driver, use_openai_chat: true do
  it 'should handle message' do
    allow_any_instance_of(Charai::OpenaiChat).to receive(:push) do |_, text, **params|
      case text
      when 'Hello'
        <<~MARKDOWN
        Hi

        ```
        driver.execute_script "1 + 1"
        ```
        MARKDOWN
      when "result is `2`"
        <<~MARKDOWN
        Hi

        ```
        driver.execute_script "1 + 2"
        ```
        MARKDOWN
      when "result is `3`"
        <<~MARKDOWN
        Hi

        ```
        driver.execute_script "2 + 2"
        ```
        MARKDOWN
      when "result is `4`"
        'OK'
      else
        raise "Unexpected text: #{text}"
      end
    end

    Capybara.current_session.visit '/'
    Capybara.current_session.driver << "Hello"
  end

  it 'should handle script evaluation error' do
    allow_any_instance_of(Charai::OpenaiChat).to receive(:push) do |_, text, **params|
      case text
      when 'Hello'
        <<~MARKDOWN
        Hi

        ```
        driver.execute_script "document.querySelector('#unknown').click()"
        ```
        MARKDOWN
      when /TypeError/
        'OK'
      else
        raise "Unexpected text: #{text}"
      end
    end

    Capybara.current_session.visit '/'
    Capybara.current_session.driver << "Hello"
  end

  it 'should handle only the last message' do
    allow_any_instance_of(Charai::OpenaiChat).to receive(:push) do |_, text, **params|
      case text
      when 'Hello'
        <<~MARKDOWN
        Hi

        ```
        driver.execute_script "1 + 1"
        driver.capture_screenshot
        driver.execute_script "1 + 2"
        ```
        MARKDOWN
      when "result is `3`"
        'OK'
      else
        raise "Unexpected text: #{text}"
      end
    end

    Capybara.current_session.visit '/'
    Capybara.current_session.driver << "Hello"
  end
end
