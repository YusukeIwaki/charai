require 'spec_helper'

RSpec.describe 'evaluate' do
  before do
    @sinatra.get('/') do
      <<~HTML
      <h1>It works!</h1>
      <p>1 + 1 = <span id="result">2</span></p>
      HTML
    end

    Capybara.current_session.visit '/'
  end

  let(:input_tool) { Capybara.current_session.driver.send(:input_tool) }

  def e(script)
    input_tool.execute_script(script)
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
