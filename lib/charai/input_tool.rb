module Charai
  # Hub class for performing actions on the browser
  # Mainly used by AI.
  class InputTool
    # callback
    #  - on_assertion_ok(description)
    #  - on_assertion_fail(description)
    #  - on_action_start(action, params)
    def initialize(browsing_context, callback: nil)
      @browsing_context = browsing_context
      @callback = callback
    end

    def on_send_message(&block)
      @message_sender = block
    end

    def assertion_ok(description)
      trigger_callback(:on_assertion_ok, description)
    end

    def assertion_fail(description)
      trigger_callback(:on_assertion_fail, description)

      if defined?(RSpec::Expectations)
        RSpec::Expectations.fail_with(description)
      elsif defined?(MiniTest::Assertion)
        raise MiniTest::Assertion, description
      else
        raise description
      end
    end

    def aria_snapshot(root_locator: 'document.body', ref: false)
      trigger_callback(:on_action_start, 'aria_snapshot', { root_locator: root_locator, ref: ref })

      current_url = @browsing_context.url
      snapshot = @browsing_context.default_realm._with_injected_script do |script|
        if ref
          body_handle = script.getprop("document.body", as_handle: true)
          result = script.call(:ariaSnapshot, body_handle, { mode: 'ai' })
          result.split("\n")
        else
          not_found = script.e("!#{root_locator}")
          if not_found
            raise ArgumentError, "Element not found: #{root_locator}"
          end
          result = script.call(:ariaSnapshot, script.h(root_locator), { mode: 'autoexpect' })
          result.split("\n")
        end
      end

      if @message_sender
        message = Agent::Message.new(text: "ARIA snapshot of #{current_url}\n\n#{snapshot}")
        @message_sender.call(message)
      end
    end

    def capture_screenshot
      trigger_callback(:on_action_start, 'capture_screenshot', {})

      current_url = @browsing_context.url
      @browsing_context.capture_screenshot(format: { type: 'png' }).tap do |binary|
        if @message_sender
          message = Agent::Message.new(
            text: "Capture of #{current_url}",
            images: [
              { png: Base64.strict_encode64(binary) },
            ],
          )
          @message_sender.call(message)
        end
      end
    end

    def click(x:, y:, delay: 50)
      trigger_callback(:on_action_start, 'click', { x: x, y: y, delay: delay })

      @browsing_context.perform_mouse_actions do |q|
        q.pointer_move(x: x.to_i, y: y.to_i)
        q.pointer_down(button: 0)
        q.pause(duration: delay)
        q.pointer_up(button: 0)
      end
    end

    def execute_script(script)
      trigger_callback(:on_action_start, 'execute_script', { script: script })

      begin
        result = @browsing_context.default_realm.script_evaluate(script)
      rescue BrowsingContext::Realm::ScriptEvaluationError => e
        result = e.message
      end

      notify_to_sender(result) unless "#{result}" == ''

      result
    end

    def execute_script_with_ref(ref, element_function_declaration)
      resolved = resolve_selector_for_ref(ref)
      trigger_callback(:on_action_start, 'execute_script_with_ref', { script: element_function_declaration, ref: ref, selector: resolved[:selector] })

      begin
        result = @browsing_context.default_realm.script_call_function(
          element_function_declaration,
          arguments: [resolved[:element_handle]])
      rescue BrowsingContext::Realm::ScriptEvaluationError => e
        result = e.message
      end

      notify_to_sender(result) unless "#{result}" == ''

      result
    end

    def on_pressing_key(key, &block)
      trigger_callback(:on_action_start, 'key_down', { key: key })

      value = convert_key(key)
      @browsing_context.perform_keyboard_actions do |q|
        q.key_down(value: value)
      end

      begin
        block.call
      ensure
        trigger_callback(:on_action_start, 'key_up', { key: key })

        @browsing_context.perform_keyboard_actions do |q|
          q.key_up(value: value)
        end
      end
    end

    def press_key(key, delay: 50)
      trigger_callback(:on_action_start, 'press_key', { key: key, delay: delay })

      value = convert_key(key)
      @browsing_context.perform_keyboard_actions do |q|
        q.key_down(value: value)
        q.pause(duration: delay)
        q.key_up(value: value)
      end
    end

    def sleep_seconds(seconds)
      trigger_callback(:on_action_start, 'sleep_seconds', { seconds: seconds })

      sleep seconds
    end

    def type_text(text, delay: 50)
      trigger_callback(:on_action_start, 'type_text', { text: text, delay: delay })

      text.each_char do |c|
        @browsing_context.perform_keyboard_actions do |q|
          q.key_down(value: c)
          q.pause(duration: delay / 2)
          q.key_up(value: c)
          q.pause(duration: delay - delay / 2)
        end
      end
    end

    # velocity:
    #  500 - weak
    # 1000 - normal
    # 2000 - strong
    def scroll_down(x: 0, y: 0, velocity: 1000)
      raise ArgumentError, 'velocity must be positive' if velocity <= 0
      trigger_callback(:on_action_start, 'scroll_down', { x: x, y: y, velocity: velocity })

      @browsing_context.perform_mouse_wheel_actions do |q|
        deceleration = SplineDeceleration.new(velocity)
        loop do
          delta_y = deceleration.calc
          break if delta_y.zero?
          q.scroll(x: x, y: y, delta_y: delta_y, duration: 16)
        end
      end
    end

    # velocity:
    #  500 - weak
    # 1000 - normal
    # 2000 - strong
    def scroll_up(x: 0, y: 0, velocity: 1000)
      raise ArgumentError, 'velocity must be positive' if velocity <= 0
      trigger_callback(:on_action_start, 'scroll_up', { x: x, y: y, velocity: velocity })

      @browsing_context.perform_mouse_wheel_actions do |q|
        deceleration = SplineDeceleration.new(velocity)
        loop do
          delta_y = -deceleration.calc
          break if delta_y.zero?
          q.scroll(x: x, y: y, delta_y: delta_y, duration: 16)
        end
      end
    end

    private

    def notify_to_sender(message)
      if @message_sender
        message = Agent::Message.new(text: "result is `#{message}`", images: [])
        @message_sender.call(message)
      end
    end

    def trigger_callback(method_name, ...)
      if @callback.respond_to?(method_name)
        @callback.public_send(method_name, ...)
      elsif @callback.is_a?(Hash) && @callback[method_name].is_a?(Proc)
        @callback[method_name].call(...)
      end
    end

    def resolve_selector_for_ref(ref)
      @browsing_context.default_realm._with_injected_script do |script|
        parsed = script.call(:parseSelector, "aria-ref=#{ref}")

        # ensure ref is attached.
        body_handle = script.getprop("document.body", as_handle: true)
        script.call(:ariaSnapshot, body_handle, { mode: 'ai' })

        document_handle = script.getprop('document', as_handle: true)
        element_handle = script.call(:querySelector, parsed, document_handle, false, as_handle: true)

        selector = script.call(:generateSelectorSimple, element_handle, { omitInternalEngines: true })

        { selector: selector, element_handle: element_handle }
      end
    end

    # ref: https://github.com/puppeteer/puppeteer/blob/puppeteer-v23.5.3/packages/puppeteer-core/src/bidi/Input.ts#L52
    # Converted using ChatGPT 4o
    def convert_key(key)
      return key if key.length == 1

      case key
      when 'Cancel'
        "\uE001"
      when 'Help'
        "\uE002"
      when 'Backspace'
        "\uE003"
      when 'Tab'
        "\uE004"
      when 'Clear'
        "\uE005"
      when 'Enter'
        "\uE007"
      when 'Shift', 'ShiftLeft'
        "\uE008"
      when 'Control', 'ControlLeft', 'Ctrl'
        "\uE009"
      when 'ControlOrMeta', 'CtrlOrMeta'
        Charai::Util.macos? ? "\uE03D" : "\uE009"
      when 'Alt', 'AltLeft'
        "\uE00A"
      when 'Pause'
        "\uE00B"
      when 'Escape'
        "\uE00C"
      when 'PageUp'
        "\uE00E"
      when 'PageDown'
        "\uE00F"
      when 'End'
        "\uE010"
      when 'Home'
        "\uE011"
      when 'ArrowLeft'
        "\uE012"
      when 'ArrowUp'
        "\uE013"
      when 'ArrowRight'
        "\uE014"
      when 'ArrowDown'
        "\uE015"
      when 'Insert'
        "\uE016"
      when 'Delete'
        "\uE017"
      when 'NumpadEqual'
        "\uE019"
      when 'Numpad0'
        "\uE01A"
      when 'Numpad1'
        "\uE01B"
      when 'Numpad2'
        "\uE01C"
      when 'Numpad3'
        "\uE01D"
      when 'Numpad4'
        "\uE01E"
      when 'Numpad5'
        "\uE01F"
      when 'Numpad6'
        "\uE020"
      when 'Numpad7'
        "\uE021"
      when 'Numpad8'
        "\uE022"
      when 'Numpad9'
        "\uE023"
      when 'NumpadMultiply'
        "\uE024"
      when 'NumpadAdd'
        "\uE025"
      when 'NumpadSubtract'
        "\uE027"
      when 'NumpadDecimal'
        "\uE028"
      when 'NumpadDivide'
        "\uE029"
      when 'F1'
        "\uE031"
      when 'F2'
        "\uE032"
      when 'F3'
        "\uE033"
      when 'F4'
        "\uE034"
      when 'F5'
        "\uE035"
      when 'F6'
        "\uE036"
      when 'F7'
        "\uE037"
      when 'F8'
        "\uE038"
      when 'F9'
        "\uE039"
      when 'F10'
        "\uE03A"
      when 'F11'
        "\uE03B"
      when 'F12'
        "\uE03C"
      when 'Meta', 'MetaLeft'
        "\uE03D"
      when 'ShiftRight'
        "\uE050"
      when 'ControlRight'
        "\uE051"
      when 'AltRight'
        "\uE052"
      when 'MetaRight'
        "\uE053"
      when 'Digit0'
        '0'
      when 'Digit1'
        '1'
      when 'Digit2'
        '2'
      when 'Digit3'
        '3'
      when 'Digit4'
        '4'
      when 'Digit5'
        '5'
      when 'Digit6'
        '6'
      when 'Digit7'
        '7'
      when 'Digit8'
        '8'
      when 'Digit9'
        '9'
      when 'KeyA'
        'a'
      when 'KeyB'
        'b'
      when 'KeyC'
        'c'
      when 'KeyD'
        'd'
      when 'KeyE'
        'e'
      when 'KeyF'
        'f'
      when 'KeyG'
        'g'
      when 'KeyH'
        'h'
      when 'KeyI'
        'i'
      when 'KeyJ'
        'j'
      when 'KeyK'
        'k'
      when 'KeyL'
        'l'
      when 'KeyM'
        'm'
      when 'KeyN'
        'n'
      when 'KeyO'
        'o'
      when 'KeyP'
        'p'
      when 'KeyQ'
        'q'
      when 'KeyR'
        'r'
      when 'KeyS'
        's'
      when 'KeyT'
        't'
      when 'KeyU'
        'u'
      when 'KeyV'
        'v'
      when 'KeyW'
        'w'
      when 'KeyX'
        'x'
      when 'KeyY'
        'y'
      when 'KeyZ'
        'z'
      when 'Semicolon'
        ';'
      when 'Equal'
        '='
      when 'Comma'
        ','
      when 'Minus'
        '-'
      when 'Period'
        '.'
      when 'Slash'
        '/'
      when 'Backquote'
        '`'
      when 'BracketLeft'
        '['
      when 'Backslash'
        '\\'
      when 'BracketRight'
        ']'
      when 'Quote'
        '"'
      else
        raise ArgumentError, "Unknown key: \"#{key}\""
      end
    end
  end
end
