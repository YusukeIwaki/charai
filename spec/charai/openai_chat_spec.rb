require 'spec_helper'

RSpec.describe Charai::OpenaiChat, skip: ENV['CI'] do
  class Callback
    def on_chat_question(content_hash)
      puts "-------Question-------"
      pp content_hash
    end

    def on_chat_answer(answer_text)
      puts "-------Answer-------"
      puts answer_text
    end
  end

  let(:configuration) do
    # Charai::OllamaConfiguration.new(
    #   endpoint_url: 'http://localhost:11434/v1/chat/completions',
    #   model: 'llava:34b' # 'llama-3-elyza-jp-8b:latest',
    # )
    Charai::AzureOpenaiConfiguration.new(
      endpoint_url: ENV['OPENAI_ENDPOINT_URL'],
      api_key: ENV['OPENAI_API_KEY'],
    )
    # Charai::GeminiOpenaiConfiguration.new(
    #   model: 'gemini-1.5-flash'
    #   api_key: ENV['GEMINI_API_KEY'],
    # )
  end

  it 'should work' do
    chat = Charai::OpenaiChat.new(configuration, callback: Callback.new, introduction: 'あなたは関西弁をしゃべるサーバーサイドエンジニアです。')
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

  it 'should work with image' do
    chat = Charai::OpenaiChat.new(configuration, introduction: 'You are a teacher for kindergarten children.')
    answer = chat.push('How many people is here?',
      images: ['https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEjF1pgCxE0BUbhiTpjxQMm8Iyjc4FYWHFzoymZ6rw3rlrgwDtePo020GQf9VZxujjnQhxqM8HKbgK2FVZVmkQ57FgleMHK2IgHj3PpO9C0Tn-6isaxStuVeU2uSdETEpt0HmuLEfXpaFc_9/s450/music_gassyou_kids_asia.png'],
    )

    expect(answer).to include('four')
  end
end
