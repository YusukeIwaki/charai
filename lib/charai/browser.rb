module Charai
  class Browser
    def self.launch(...)
      BrowserLauncher.new.launch(...)
    end

    def initialize(web_socket, debug_protocol: false)
      @web_socket = web_socket
      @debug_protocol = debug_protocol
      web_socket.on_message do |message|
        handle_received_message_from_websocket(JSON.parse(message))
      end

      bidi_call_async('session.new', {
        capabilities: {
          alwaysMatch: {
            acceptInsecureCerts: false,
            webSocketUrl: true,
          },
        },
      }).value!
    end

    def close
      bidi_call_async('browser.close').value!
      @web_socket.close
      @thread.join
    end

    def bidi_call_async(method_, params = {})
      with_message_id do |message_id|
        @message_results[message_id] = Concurrent::Promises.resolvable_future

        send_message_to_websocket({
          id: message_id,
          method: method_,
          params: params,
        })

        @message_results[message_id]
      end
    end

    private

    def with_message_id(&block)
      unless @message_id
        @message_id = 1
        @message_results = {}
      end

      message_id = @message_id
      @message_id += 1
      block.call(message_id)
    end

    def send_message_to_websocket(payload)
      debug_print_send(payload)
      message = JSON.generate(payload)
      @web_socket.send_text(message)
    end

    def handle_received_message_from_websocket(payload)
      debug_print_recv(payload)

      if payload['id']
        if promise = @message_results.delete(payload['id'])
          case payload['type']
          when 'success'
            promise.fulfill(payload['result'])
          when 'error'
            promise.reject(Error.new("#{payload['error']}: #{payload['message']}\n#{payload['stacktrace']}"))
          end
        end
      end
    end

    class Error < StandardError ; end

    def debug_print_send(hash)
      return unless @debug_protocol

      puts "SEND > #{hash}"
    end

    def debug_print_recv(hash)
      return unless @debug_protocol

      puts "RECV < #{hash}"
    end
  end
end
