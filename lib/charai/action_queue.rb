module Charai
  class ActionQueue
    def initialize
      @actions = []
    end

    def to_a
      @actions
    end

    def pause(duration:)
      @actions << { type: 'pause', duration: duration }
    end

    def key_down(value:)
      @actions << { type: 'keyDown', value: value }
    end

    def key_up(value:)
      @actions << { type: 'keyUp', value: value }
    end

    # button: 0 for left, 1 for middle, 2 for right
    def pointer_down(button:)
      @actions << { type: 'pointerDown', button: button }
    end

    def pointer_move(x:, y:, duration: nil)
      @actions << { type: 'pointerMove', x: x, y: y, duration: duration }.compact
    end

    # button: 0 for left, 1 for middle, 2 for right
    def pointer_up(button:)
      @actions << { type: 'pointerUp', button: button }
    end

    def scroll(x:, y:, delta_x: 0, delta_y: 0, duration: nil)
      @actions << { type: 'scroll', x: x, y: y, deltaX: delta_x, deltaY: delta_y, duration: duration }.compact
    end
  end
end
