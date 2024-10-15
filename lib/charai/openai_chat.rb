require 'net/http'
require 'json'

module Charai
  class OpenaiChat
    def initialize(introduction: nil)
      @endpoint_url = 'http://localhost:11434/v1/chat/completions'
      @model = 'llama-3-elyza-jp-8b:latest'
      @api_key = 'hogehogehogehoge'
      @introduction = introduction
      clear
    end

    def clear
      @messages = []
      if @introduction
        @messages << { role: 'system', content: @introduction }
      end
    end

    def push(question)
      @messages << { role: 'user', content: question }
      fetch_openai.tap do |answer|
        @messages << { role: 'assistant', content: answer }
      end
    end

    def pop
      @messages.pop
      @messages.pop[:content]
    end

    private

    def fetch_openai
      uri = URI(@endpoint_url)

      resp = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https', read_timeout: 120) do |http|
        http.post(
          uri,
          {
            model: @model,
            messages: @messages,
          }.to_json,
          {
            'api-key' => @api_key,
            'Content-Type' => 'application/json',
            'Accept' => 'application/json',
          },
        )
      end
      body = JSON.parse(resp.body)
      body.dig('choices', 0, 'message', 'content')
    end
  end
end
