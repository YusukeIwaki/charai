require 'spec_helper'

RSpec.describe 'keyboard' do
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

  it 'should press key' do
    e <<~JAVASCRIPT
    document.querySelector('textarea').focus()
    JAVASCRIPT

    input_tool.press_key('a')
    input_tool.on_pressing_key('Shift') do
      input_tool.press_key('b')
    end
    expect(e("document.querySelector('textarea').value")).to eq('aB')

    e <<~JAVASCRIPT
    document.querySelector('textarea').focus()
    JAVASCRIPT

    input_tool.on_pressing_key('ControlOrMeta') do
      input_tool.press_key('a')
      input_tool.press_key('c')
      input_tool.press_key('v')
      input_tool.press_key('v')
    end
    input_tool.press_key('x')
    expect(e("document.querySelector('textarea').value")).to eq('aBaBx')
  end

  it 'should type text' do
    e <<~JAVASCRIPT
    document.querySelector('textarea').focus()
    JAVASCRIPT

    input_tool.type_text('aB🍰')
    expect(e("document.querySelector('textarea').value")).to eq('aB🍰')
  end
end
