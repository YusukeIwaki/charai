require 'base64'
require 'json'
require 'net/http'
require 'uri'

module Charai
  class OpenaiChat
    # callback
    #  - on_chat_start
    #  - on_chat_question(content: Array|String)
    #  - on_chat_answer(answer_text)
    #  - on_chat_conversation(content, answer_text)
    def initialize(introduction: nil, callback: nil)
      @endpoint_url = ENV['OPENAI_ENDPOINT_URL'] || 'http://localhost:11434/v1/chat/completions'
      unless ENV['OPENAI_ENDPOINT_URL']
        # Specify 'model' option only for local execution on Ollama
        @model = 'llava:34b' #'llama-3-elyza-jp-8b:latest'
      end
      @api_key = ENV['OPENAI_API_KEY'] || 'hogehogehogehoge'
      @introduction = introduction
      @callback = callback
      @mutex = Mutex.new
      clear
    end

    def clear
      trigger_callback(:on_chat_start)

      @messages = []
      if @introduction
        @messages << { role: 'system', content: @introduction }
      end
    end

    # .push('How are you?')
    # .push('How many people is here?', images: [ { jpg: 'xXxXxxxxxxxxx' }, { png: 'xXxXxxxxxxxxx' } ])
    def push(question, images: [])
      content = build_question(question, images)
      message = {
        role: 'user',
        content: content,
      }

      @mutex.synchronize do
        trigger_callback(:on_chat_question, content)
        fetch_openai(message).tap do |answer|
          trigger_callback(:on_chat_answer, answer)
          trigger_callback(:on_chat_conversation, content, answer)

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
      uri = URI.parse(url)

      response = Net::HTTP.get_response(uri)

      if response.is_a?(Net::HTTPSuccess)
        image_data = response.body
        mime_type = response['content-type']

        base64_image = Base64.strict_encode64(image_data)

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

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https', read_timeout: 120) do |http|
        http.post(
          uri,
          {
            model: @model,
            messages: with_message_history(message),
          }.compact.to_json,
          {
            'api-key' => @api_key,
            'Content-Type' => 'application/json',
            'Accept' => 'application/json',
          },
        )
      end
      if response.is_a?(Net::HTTPSuccess)
        body = JSON.parse(response.body)
        body.dig('choices', 0, 'message', 'content')
      else
        raise "Failed to fetch OpenAI: #{response.code} #{response.message}"
      end
    end

    def with_message_history(new_message, omit_images_except_last: 3)
      Enumerator.new do |out|
        len = @messages.size
        @messages.each_with_index do |message, i|
          if i < len - omit_images_except_last && message[:content].is_a?(Array)
            out << message.merge(content: message[:content].find { |c| c[:type] == 'text'}[:text])
          else
            out << message
          end
        end
        out << new_message
      end.to_a
    end

    def trigger_callback(method_name, ...)
      if @callback.respond_to?(method_name)
        @callback.public_send(method_name, ...)
      elsif @callback.is_a?(Hash) && @callback[method_name].is_a?(Proc)
        @callback[method_name].call(...)
      end
    end
  end
end
