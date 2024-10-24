module Charai
  class Agent
    class Message < Data.define(:text, :images)
      def initialize(text:, images: [])
        super(text: text, images: images)
      end
    end


    def initialize(input_tool:, openai_chat:)
      input_tool.on_send_message do |message|
        send_message_to_openai_chat(message)
      end
      @sandbox = Sandbox.new(input_tool)
      @openai_chat = openai_chat
    end

    def <<(text)
      message = Message.new(text: text)
      send_message_to_openai_chat(message)
    end

    attr_reader :last_message

    private

    def send_message_to_openai_chat(message)
      if @should_use_message_queue
        @message_queue << message
      else
        answer = @openai_chat.push(message.text, images: message.images)
        @last_message = answer
        handle_message_from_openai_chat(answer)
      end
    end

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

    class HandleMessageError < StandardError ; end

    def handle_message_from_openai_chat(answer)
      with_message_queuing do
        with_aggregating_failures do
          begin
            answer.scan(/```[a-zA-Z]*\n(.*?)\n```/m).map(&:first).each do |code|
              if code.include?('`') # Avoid OS shell execution.
                raise HandleMessageError, "It is not allowed to use backquote"
              end
              @sandbox.instance_eval(code)
            end
          rescue HandleMessageError => e
            send_message_to_openai_chat(Message.new(text: e.message))
          rescue Browser::Error => e
            send_message_to_openai_chat(Message.new(text: "Error: #{e.message}"))
          rescue => e
            send_message_to_openai_chat(Message.new(text: "ERROR: #{e.message}"))
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
