require 'base64'
require 'json'
require 'net/http'
require 'uri'

module Charai
  class OpenaiChat
    def initialize(introduction: nil, debug_message: false)
      @endpoint_url = ENV['OPENAI_ENDPOINT_URL'] || 'http://localhost:11434/v1/chat/completions'
      unless ENV['OPENAI_ENDPOINT_URL']
        # Specify 'model' option only for local execution on Ollama
        @model = 'llava:34b' #'llama-3-elyza-jp-8b:latest'
      end
      @api_key = ENV['OPENAI_API_KEY'] || 'hogehogehogehoge'
      @introduction = introduction
      @debug_message = debug_message
      @mutex = Mutex.new
      clear
    end

    def clear
      @messages = []
      if @introduction
        @messages << { role: 'system', content: @introduction }
      end
    end

    # .push('How are you?')
    # .push('How many people is here?', images: [ { jpg: 'xXxXxxxxxxxxx' }, { png: 'xXxXxxxxxxxxx' } ])
    def push(question, images: [])
      message = {
        role: 'user',
        content: build_question(question, images),
      }

      @mutex.synchronize do
        debug_print_messages(message)
        fetch_openai(message).tap do |answer|
          debug_print_answer(answer)
          @messages << message
          @messages << { role: 'assistant', content: answer }
        end
      end
    end

    def pop
      @mutex.synchronize do
        @messages.pop
        @messages.pop[:content]
      end
    end

    private

    def build_question(question, images)
      if images.empty?
        question
      else
        [
          {
            type: 'text',
            text: question,
          },
          *(images.map { |image| build_image_payload(image) }),
        ]
      end
    end

    def build_image_payload(image)
      if image.is_a?(String) && image.start_with?('http')
        return build_image_payload(fetch_image_url(image))
      end

      raise ArgumentError, "image must be a Hash, but got #{image.class}" unless image.is_a?(Hash)
      raise ArgumentError, "image must have only one key, but got #{image.keys}" unless image.keys.size == 1
      type = image.keys.first
      raise ArgumentError, "image key must be one of [:jpg, :jpeg, :png], but got #{type}" unless %i[jpg jpeg png].include?(type)

      b64 = image[type]

      {
        type: 'image_url',
        image_url: {
          url: "data:image/#{type};base64,#{b64}",
        },
      }
    end

    def fetch_image_url(url)
      # URLをパース
      uri = URI.parse(url)

      # HTTPリクエストを作成して画像データを取得
      response = Net::HTTP.get_response(uri)

      # レスポンスボディが画像データ、content-typeヘッダがMIMEタイプ
      if response.is_a?(Net::HTTPSuccess)
        image_data = response.body
        mime_type = response['content-type']

        # Base64エンコード
        base64_image = Base64.strict_encode64(image_data)

        # MIMEタイプに応じたハッシュを生成
        case mime_type
        when 'image/png'
          { png: base64_image }
        when 'image/jpeg'
          { jpeg: base64_image }
        else
          raise "Unsupported image type: #{mime_type}"
        end
      else
        raise "Failed to fetch image: #{response.code} #{response.message}"
      end
    end

    def fetch_openai(message)
      uri = URI(@endpoint_url)

      resp = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https', read_timeout: 120) do |http|
        http.post(
          uri,
          {
            model: @model,
            messages: @messages + [message],
          }.compact.to_json,
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

    def debug_print_messages(new_message)
      return unless @debug_message

      puts 'SEND > '
      @messages.each { |message| print_message(message) }
      print_message(new_message)
      puts "|---"
    end

    def print_message(message)
      if message[:content].is_a?(String)
        puts "|  #{message[:role]}: #{message[:content]}"
      else
        puts "|  #{message[:role]}: #{JSON.pretty_generate(message[:content])}"
      end
    end

    def debug_print_answer(answer)
      return unless @debug_message

      puts "RECV < #{answer}"
      puts "|---"
    end
  end
end
