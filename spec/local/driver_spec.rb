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
    expect(Capybara.current_session.driver.last_message).to eq('OK')
  end

  it 'should handle illegal use of backquote' do
    allow_any_instance_of(Charai::OpenaiChat).to receive(:push) do |_, text, **params|
      case text
      when 'Hello'
        <<~MARKDOWN
        Hi

        ```
        driver.execute_script(`
        var a=3;
        a + 2
        `)
        ```
        MARKDOWN
      when /not allowed to use backquote/
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
        'ERROR'
      else
        raise "Unexpected text: #{text}"
      end
    end

    Capybara.current_session.visit '/'
    Capybara.current_session.driver << "Hello"
    expect(Capybara.current_session.driver.last_message).to eq('ERROR')
  end

  it 'should handle multiple messages' do
    @sinatra.get('/') do
      <<~HTML
      <h1>It works!</h1>
      <input type="text" id="aa"/>
      HTML
    end

    allow_any_instance_of(Charai::OpenaiChat).to receive(:push) do |_, text, **params|
      case text
      when 'Hello'
        <<~MARKDOWN
        Hi

        ```
        driver.execute_script "document.querySelector('#aa').value = '1'"
        ```

        and then

        ```
        driver.execute_script "document.querySelector('#aa').value += '1'"
        ```

        and then

        ```
        driver.execute_script "document.querySelector('#aa').value += '2'"
        ```

        and then

        ```
        driver.execute_script "document.querySelector('#aa').value"
        ```
        MARKDOWN
      when "result is `112`"
        'OK'
      else
        raise "Unexpected text: #{text}"
      end
    end

    Capybara.current_session.visit '/'
    Capybara.current_session.driver << "Hello"
    expect(Capybara.current_session.driver.last_message).to eq('OK')
  end

  it 'should reply only for the last message' do
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

  it 'should work with assertion_ok and assertion_fail' do
    allow_any_instance_of(Charai::OpenaiChat).to receive(:push) do |_, text, **params|
      case text
      when 'OK'
        <<~MARKDOWN
        Hi

        ```
        driver.assertion_ok("test item 1")
        driver.assertion_ok("test item 2")
        driver.assertion_ok("test item 3")
        ```
        MARKDOWN
      when "NG"
        <<~MARKDOWN
        Hi

        ```
        driver.assertion_ok("test item 1")
        driver.assertion_fail("test item 2")
        driver.assertion_fail("test item 3")
        ```
        MARKDOWN
      else
        raise "Unexpected text: #{text}"
      end
    end

    Capybara.current_session.visit '/'

    Capybara.current_session.driver << "OK"

    expect {
      Capybara.current_session.driver << "NG"
    }.to raise_error(RSpec::Expectations::MultipleExpectationsNotMetError) do |error|
      expect(error.message).to include("test item 2")
      expect(error.message).to include("test item 3")
    end
  end
end
