module Charai
  # Hub class for performing actions on the browser
  # Mainly used by AI.
  class InputTool
    def initialize(browsing_context)
      @browsing_context = browsing_context
    end

    def click(x:, y:, delay: 50)
      @browsing_context.perform_mouse_actions do |q|
        q.pointer_move(x: x, y: y)
        q.pointer_down(button: 0)
        q.pause(duration: delay)
        q.pointer_up(button: 0)
      end
    end

    def execute_script(script)
      @browsing_context.default_realm.script_evaluate(script)
    end

    def on_pressing_key(key, &block)
      value = convert_key(key)
      @browsing_context.perform_keyboard_actions do |q|
        q.key_down(value: value)
      end

      block.call

      @browsing_context.perform_keyboard_actions do |q|
        q.key_up(value: value)
      end
    end

    def press_key(key, delay: 50)
      value = convert_key(key)
      @browsing_context.perform_keyboard_actions do |q|
        q.key_down(value: value)
        q.pause(duration: delay)
        q.key_up(value: value)
      end
    end

    def sleep_seconds(seconds)
      sleep seconds
    end

    def type_text(text, delay: 50)
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
