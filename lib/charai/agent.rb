module Charai
  class Agent
    class Message < Struct.new(:text, :images, keyword_init: true)
      def text
        self[:text] or raise "text is required"
      end

      def images
        self[:images] || []
      end
    end


    def initialize(input_tool:, openai_chat:)
      input_tool.on_send_message do |message|
        send_message_to_openai_chat(message)
      end
      @sandbox = Sandbox.new(input_tool)
      @openai_chat = openai_chat
    end

    def send_message_to_openai_chat(message)
      if @pending
        @message_queue << message
      else
        answer = @openai_chat.push(message.text, images: message.images)
        handle_message_from_openai_chat(answer)
      end
    end

    private

    def pending!
      @pending = true
      @message_queue = []
    end

    def unpending!
      @pending = false

      # Handle only the last message
      if (message = @message_queue.last)
        send_message_to_openai_chat(message)
      end
    end

    def handle_message_from_openai_chat(answer)
      pending!
      begin
        answer.scan(/```\n(.*)\n```/m).map(&:first).each do |code|
          @sandbox.instance_eval(code)
          break
        end
      ensure
        unpending!
      end
    end

    class Sandbox
      def initialize(input_tool)
        @input_tool = input_tool
      end

      private

      def driver
        @input_tool
      end
    end
  end
end
