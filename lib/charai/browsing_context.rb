require 'base64'

module Charai
  class BrowsingContext
    def initialize(browser, context_id)
      @browser = browser
      @context_id = context_id
    end

    def navigate(url, wait: :interactive)
      bidi_call_async('browsingContext.navigate', {
        url: url,
        wait: wait,
      }.compact).value!
    end

    def realms
      result = bidi_call_async('script.getRealms').value!
      result['realms'].map do |realm|
        Realm.new(
          browsing_context: self,
          id: realm['realm'],
          origin: realm['origin'],
          type: realm['type'],
        )
      end
    end

    def default_realm
      realms.find { |realm| realm.type == 'window' }
    end

    def activate
      bidi_call_async('browsingContext.activate').value!
    end

    def capture_screenshot(origin: nil, format: nil, clip: nil)
      result = bidi_call_async('browsingContext.captureScreenshot', {
        origin: origin,
        format: format,
        clip: clip,
      }.compact).value!

      Base64.strict_decode64(result[:data])
    end

    def close(prompt_unload: nil)
      bidi_call_async('browsingContext.close', {
        promptUnload: prompt_unload,
      }.compact).value!
    end

    def perform_keyboard_actions(&block)
      q = ActionQueue.new
      block.call(q)
      perform_actions([{
        type: 'key',
        id: '__charai_keyboard',
        actions: q.to_a,
      }])
    end

    def perform_mouse_actions(&block)
      q = ActionQueue.new
      block.call(q)
      perform_actions([{
        type: 'pointer',
        id: '__charai_mouse',
        actions: q.to_a,
      }])
    end

    def perform_mouse_wheel_actions(&block)
      q = ActionQueue.new
      block.call(q)
      perform_actions([{
        type: 'wheel',
        id: '__charai_wheel',
        actions: q.to_a,
      }])
    end

    def reload(ignore_cache: nil, wait: nil)
      bidi_call_async('browsingContext.reload', {
        ignoreCache: ignore_cache,
        wait: wait,
      }.compact).value!
    end

    def set_viewport(width:, height:, device_pixel_ratio: nil)
      bidi_call_async('browsingContext.setViewport', {
        viewport: {
          width: width,
          height: height,
        },
        devicePixelRatio: device_pixel_ratio,
      }.compact).value!
    end

    def traverse_history(delta)
      bidi_call_async('browsingContext.traverseHistory', {
        delta: delta,
      }).value!
    end

    def url
      @url
    end

    def _update_url(url)
      @url = url
    end

    private

    def bidi_call_async(method_, params = {})
      @browser.bidi_call_async(method_, params.merge({ context: @context_id }))
    end

    def perform_actions(actions)
      bidi_call_async('input.performActions', {
        actions: actions,
      }).value!
    end

    class Realm
      def initialize(browsing_context:, id:, origin:, type: nil)
        @browsing_context = browsing_context
        @id = id
        @origin = origin
        @type = type
      end

      class ScriptEvaluationError < StandardError; end

      def script_evaluate(expression)
        result = @browsing_context.send(:bidi_call_async, 'script.evaluate', {
          expression: expression,
          target: { realm: @id },
          awaitPromise: true,
        }).value!

        if result['type'] == 'exception'
          raise ScriptEvaluationError, result['exceptionDetails']['text']
        end

        deserialize(result['result'])
      end

      attr_reader :type

      private

      # ref: https://github.com/puppeteer/puppeteer/blob/puppeteer-v23.5.3/packages/puppeteer-core/src/bidi/Deserializer.ts#L21
      # Converted using ChatGPT 4o
      def deserialize(result)
        case result["type"]
        when 'array'
          result['value']&.map { |value| deserialize(value) }
        when 'set'
          result['value']&.each_with_object(Set.new) do |value, acc|
            acc.add(deserialize(value))
          end
        when 'object'
          result['value']&.each_with_object({}) do |tuple, acc|
            key, value = tuple
            acc[key] = deserialize(value)
          end
        when 'map'
          result['value']&.each_with_object({}) do |tuple, acc|
            key, value = tuple
            acc[key] = deserialize(value)
          end
        when 'promise'
          {}
        when 'regexp'
          flags = 0
          result['value']['flags']&.each_char do |flag|
            case flag
            when 'm'
              flags |= Regexp::MULTILINE
            when 'i'
              flags |= Regexp::IGNORECASE
            end
          end
          Regexp.new(result['value']['pattern'], flags)
        when 'date'
          Date.parse(result['value'])
        when 'undefined'
          nil
        when 'null'
          nil
        when 'number', 'bigint', 'boolean', 'string'
          result['value']
        else
          raise ArgumentError, "Unknown type: #{result['type']}"
        end
      end
    end
  end
end
