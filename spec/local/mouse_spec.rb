require 'spec_helper'

RSpec.describe 'mouse' do
  before do
    @sinatra.get('/') do
      <<~HTML
      <h1>It works!</h1>
      <input name="title" type="text"/>
      <textarea name="description"></textarea>
      HTML
    end

    Capybara.current_session.visit '/'
  end

  let(:input_tool) { Capybara.current_session.driver.send(:input_tool) }

  def e(script)
    input_tool.execute_script(script)
  end

  it 'should click' do
    rect_json = e <<~JAVASCRIPT
    JSON.stringify(document.querySelector('textarea').getBoundingClientRect())
    JAVASCRIPT
    # [1] pry(#<RSpec::ExampleGroups::Mouse>)> rect
    # => {"x"=>201,
    #  "y"=>68.83332824707031,
    #  "width"=>164.6666717529297,
    #  "height"=>40,
    #  "top"=>68.83332824707031,
    #  "right"=>365.6666717529297,
    #  "bottom"=>108.83332824707031,
    #  "left"=>201}
    rect = JSON.parse(rect_json)
    center = { x: rect['x'] + rect['width'] / 2, y: rect['y'] + rect['height'] / 2 }

    input_tool.click(**center)
    input_tool.press_key('a')
    expect(e("document.querySelector('input').value")).to eq('')
    expect(e("document.querySelector('textarea').value")).to eq('a')
  end
end
