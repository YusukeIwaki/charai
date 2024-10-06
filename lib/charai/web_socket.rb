require 'openssl'
require 'socket'
require 'websocket/driver'

module Charai
  # ref: https://github.com/rails/rails/blob/master/actioncable/lib/action_cable/connection/client_socket.rb
  # ref: https://github.com/cavalle/chrome_remote/blob/master/lib/chrome_remote/web_socket_client.rb
  class WebSocket
    class DriverImpl # providing #url, #write(string)
      class SecureSocketFactory
        def initialize(host, port)
          @host = host
          @port = port || 443
        end

        def create
          tcp_socket = TCPSocket.new(@host, @port)
          OpenSSL::SSL::SSLSocket.new(tcp_socket).tap(&:connect)
        end
      end

      def initialize(url)
        @url = url

        endpoint = URI.parse(url)
        @socket =
          if endpoint.scheme == 'wss'
            SecureSocketFactory.new(endpoint.host, endpoint.port).create
          else
            TCPSocket.new(endpoint.host, endpoint.port)
          end
      end

      attr_reader :url

      def write(data)
        @socket.write(data)
      rescue Errno::EPIPE
        raise EOFError.new('already closed')
      rescue Errno::ECONNRESET
        raise EOFError.new('closed by remote')
      end

      def readpartial(maxlen = 1024)
        @socket.readpartial(maxlen)
      rescue Errno::ECONNRESET
        raise EOFError.new('closed by remote')
      end

      def dispose
        @socket.close
      end
    end

    STATE_CONNECTING = 0
    STATE_OPENED = 1
    STATE_CLOSING = 2
    STATE_CLOSED = 3

    def initialize(url:, max_payload_size: 256 * 1024 * 1024)
      @impl = DriverImpl.new(url)
      @driver = ::WebSocket::Driver.client(@impl, max_length: max_payload_size)

      setup
      @driver.start

      Thread.new do
        wait_for_data until @ready_state >= STATE_CLOSING
      rescue EOFError
        # Google Chrome was gone.
        # We have nothing todo. Just finish polling.
        if @ready_state < STATE_CLOSING
          handle_on_close(reason: 'Going Away', code: 1001)
        end
      end
    end

    private def setup
      @ready_state = STATE_CONNECTING
      @driver.on(:open) do
        @ready_state = STATE_OPENED
        handle_on_open
      end
      @driver.on(:close) do |event|
        @ready_state = STATE_CLOSED
        handle_on_close(reason: event.reason, code: event.code)
      end
      @driver.on(:error) do |event|
        unless handle_on_error(error_message: event.message)
          raise event.message
        end
      end
      @driver.on(:message) do |event|
        handle_on_message(event.data)
      end
    end

    private def wait_for_data
      @driver.parse(@impl.readpartial)
    end

    # @param message [String]
    def send_text(message)
      return if @ready_state >= STATE_CLOSING
      @driver.text(message)
    end

    def close(code: 1000, reason: "")
      return if @ready_state >= STATE_CLOSING
      @ready_state = STATE_CLOSING
      @driver.close(reason, code)
      @impl.dispose
    end

    def on_open(&block)
      @on_open = block
    end

    # @param block [Proc(reason: String, code: Numeric)]
    def on_close(&block)
      @on_close = block
    end

    # @param block [Proc(error_message: String)]
    def on_error(&block)
      @on_error = block
    end

    def on_message(&block)
      @on_message = block
    end

    private def handle_on_open
      @on_open&.call
    end

    private def handle_on_close(reason:, code:)
      @on_close&.call(reason, code)
    end

    private def handle_on_error(error_message:)
      return false if @on_error.nil?

      @on_error.call(error_message)
    end

    private def handle_on_message(data)
      return if @ready_state != STATE_OPENED

      @on_message&.call(data)
    end
  end
end