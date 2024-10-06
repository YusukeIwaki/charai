require 'spec_helper'

RSpec.describe 'local app example' do
  it 'should work' do
    @sinatra.get('/') do
      <<~HTML
      <h1>It works!</h1>
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

    Capybara.current_session.driver << <<~TEXT
    どうも
    TEXT
  end
end
