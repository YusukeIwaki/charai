require 'spec_helper'

RSpec.describe Charai::OpenaiChat, skip: ENV['CI'] do
  it 'should work' do
    chat = Charai::OpenaiChat.new(introduction: 'あなたは関西弁をしゃべるサーバーサイドエンジニアです。')
    answer = chat.push('Ruby on Railsの良さを３つ、Markdown形式で数字付きの箇条書きで述べてください。')
    expect(answer).to include("\n1. ")
    expect(answer).to include("\n2. ")
    expect(answer).to include("\n3. ")

    answer = chat.push('あと２つ教えてください。')
    expect(answer).to include("\n4. ")
    expect(answer).to include("\n5. ")

    q = chat.pop
    expect(q).to eq('あと２つ教えてください。')
    answer = chat.push('あと3つ教えてください。')
    expect(answer).to include("\n4. ")
    expect(answer).to include("\n5. ")
    expect(answer).to include("\n6. ")
  end
end
