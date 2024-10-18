require 'spec_helper'

RSpec.describe 'local app example', use_openai_chat: true do
  before do
    allow_any_instance_of(Charai::OpenaiChat).to receive(:push) do |_, text, **params|
      case text
      when /Click the link/
        <<~MARKDOWN
        わからん

        ```
        driver.execute_script "JSON.stringify(document.querySelector('a').getBoundingClientRect())"
        ```
        MARKDOWN
      when /\{.*\}/
        rect = JSON.parse(text.match(/\{.*\}/)[0])
        center = { x: rect['x'] + rect['width'] / 2, y: rect['y'] + rect['height'] / 2 }

        <<~MARKDOWN
        ```
        driver.click(x: #{center[:x]}, y: #{center[:y]})
        driver.sleep_seconds(2)
        driver.capture_screenshot
        ```
        MARKDOWN
      when /^Capture of http/
        url = text.match(/Capture of (.*)/)[1]
        if url.end_with?('page-0.html')
          <<~MARKDOWN
          ```
          puts "OK"
          ```
          MARKDOWN
        else
          <<~MARKDOWN
          ```
          puts "RETRY"
          driver.execute_script "document.querySelector('a').click()"
          driver.sleep_seconds(2)
          driver.capture_screenshot
          ```
          MARKDOWN
        end
      else
        raise "Unexpected text: #{text}"
      end
    end
  end

  it 'should work' do
    @sinatra.get('/') do
      <<~HTML
      <h1>It works!</h1>
      <textarea></textarea>
      <script type="text/javascript">
      for (let i = 0; i < 100; i++) {
        const a = document.createElement('a')
        a.href = `./page-${i}.html`
        a.innerText = `Link to Page ${i}`
        document.body.appendChild(a)
      }
      document.querySelectorAll("a").forEach(a => {
        a.style.display = 'none'
      });
      setTimeout(() => {
        document.querySelectorAll("a").forEach(a => {
          a.style.display = 'block'
        });
      }, 5000)</script>
      HTML
    end

    Capybara.current_session.visit '/'
    Capybara.current_session.driver << 'Click the link'
  end
end
