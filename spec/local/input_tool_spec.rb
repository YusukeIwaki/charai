require 'spec_helper'

RSpec.describe Charai::InputTool do
  before do
    mocked_openai_chat = []
    allow_any_instance_of(Charai::Driver).to receive(:openai_chat).and_return(mocked_openai_chat)
  end

  let(:input_tool) { Charai::InputTool.new(Capybara.current_session.driver.send(:browsing_context)) }

  def e(script)
    input_tool.execute_script(script)
  end

  describe 'evaluate' do
    before do
      @sinatra.get('/') do
        <<~HTML
        <h1>It works!</h1>
        <p>1 + 1 = <span id="result">2</span></p>
        HTML
      end

      Capybara.current_session.visit '/'
    end

    it 'should evaluate' do
      expect(e('1 + 1')).to eq(2)
      expect(e('Math.PI')).to be_between(3.141592, 3.141593)
      expect(e('[3, "4", 5.0, { a: 3, b: "4" }]')).to eq([3, "4", 5.0, { 'a' => 3, 'b' => "4" }])
      expect(e('({ a: 3, b: "4", c: [] })')).to eq({ 'a' => 3, 'b' => "4", 'c' => [] })
      expect(e('new Date("2021-01-01")')).to eq(Date.new(2021, 1, 1))
      expect(e('new RegExp("A*b", "mi")')).to eq(/A*b/mi)
      expect(e('new RegExp("A*b", "m")')).to eq(/A*b/m)
      expect(e('new RegExp("A*b", "g")')).to eq(/A*b/)

      expect(e("document.getElementById('result').getBoundingClientRect()")).to be_nil
    end
  end

  describe 'keyboard' do
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

  describe 'mouse' do
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
end
