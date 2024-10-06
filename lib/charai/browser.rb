module Charai
  class Browser
    def self.launch(...)
      BrowserLauncher.new.launch(...)
    end

    def initialize(web_socket, debug_protocol: false)
      @web_socket = web_socket
      @debug_protocol = debug_protocol
      @browsing_contexts = {}

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
      sync_browsing_contexts
      bidi_call_async('session.subscribe', {
        events: %w[browsingContext],
      }) # do no await
    end

    def create_browsing_context
      result = bidi_call_async('browsingContext.create', { type: :tab, userContext: :default }).value!
      browsing_context_id = result['context']
      @browsing_contexts[browsing_context_id] ||= BrowsingContext.new(self, browsing_context_id)
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
      elsif payload['type'] == 'event'
        handle_received_event(payload['method'], payload['params'])
      end
    end

    class Error < StandardError ; end

    def handle_received_event(method_, params)
      case method_
      when 'browsingContext.contextCreated'
        browsing_context_id = params['context']
        @browsing_contexts[browsing_context_id] ||= BrowsingContext.new(self, browsing_context_id)
        if params['url']
          @browsing_contexts[browsing_context_id]._update_url(params['url'])
        end
      when 'browsingContext.contextDestroyed'
        browsing_context_id = params['context']
        @browsing_contexts.delete(browsing_context_id)
      when 'browsingContext.domContentLoaded'
        browsing_context_id = params['context']
        if params['url']
          @browsing_contexts[browsing_context_id]&._update_url(params['url'])
        end
      end
    end

    def sync_browsing_contexts
      result = bidi_call_async('browsingContext.getTree').value!
      browsing_contexts = result['contexts']

      extra_context_ids = @browsing_contexts.keys - browsing_contexts.map { |context| context['context'] }
      extra_context_ids.each do |context_id|
        @browsing_contexts.delete(context_id)
      end
      result['contexts'].each do |context|
        @browsing_contexts[context['context']] ||= BrowsingContext.new(self, context)
        if context['url']
          @browsing_contexts[context['context']]._update_url(context['url'])
        end
      end
    end

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
