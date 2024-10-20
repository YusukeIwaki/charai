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
      if @should_use_message_queue
        @message_queue << message
      else
        answer = @openai_chat.push(message.text, images: message.images)
        handle_message_from_openai_chat(answer)
      end
    end

    private

    def with_aggregating_failures(&block)
      if defined?(RSpec::Expectations)
        label = nil
        metadata = {}
        RSpec::Expectations::FailureAggregator.new(label, metadata).aggregate(&block)
      else
        block.call
      end
    end

    def with_message_queuing(&block)
      @should_use_message_queue = true
      @message_queue = []

      begin
        block.call
      ensure
        @should_use_message_queue = false
        # Handle only the last message
        if (message = @message_queue.last)
          send_message_to_openai_chat(message)
        end
      end
    end

    def handle_message_from_openai_chat(answer)
      with_message_queuing do
        with_aggregating_failures do
          answer.scan(/```[a-zA-Z]*\n(.*?)\n```/m).map(&:first).each do |code|
            @sandbox.instance_eval(code)
          end
        end
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
