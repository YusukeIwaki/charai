module Charai
  # ref: https://android.googlesource.com/platform/frameworks/base/+/master/core/java/android/widget/OverScroller.java
  # Converted using ChatGPT 4o
  #
  # Usage:
  # deceleration = SplineDeceleration.new(200)
  # loop do
  #   delta = deceleration.calc
  #   sleep 0.016 # 60fps
  #   break if delta.zero?
  # end

  class SplineDeceleration
    DECELERATION_RATE = Math.log(0.78) / Math.log(0.9)
    INFLEXION = 0.35
    START_TENSION = 0.5
    END_TENSION = 1.0
    P1 = START_TENSION * INFLEXION
    P2 = 1.0 - END_TENSION * (1.0 - INFLEXION)
    NB_SAMPLES = 100

    attr_reader :current_velocity, :current_position

    def initialize(initial_velocity)
      @initial_velocity = initial_velocity
      @current_velocity = initial_velocity
      @physical_coeff = 1000
      @elapsed_time = 0 # 累積時間を管理
      @duration = calculate_duration
      @distance = calculate_distance
      @previous_position = 0 # 前回の位置を保持
      @current_position = 0

      # スプラインテーブルを構築
      @spline_position = Array.new(NB_SAMPLES + 1)
      @spline_time = Array.new(NB_SAMPLES + 1)
      build_spline_tables
    end

    def calculate_distance
      l = Math.log(INFLEXION * @initial_velocity.abs / @physical_coeff)
      decel_minus_one = DECELERATION_RATE - 1.0
      @physical_coeff * Math.exp(DECELERATION_RATE / decel_minus_one * l)
    end

    def calculate_duration
      l = Math.log(INFLEXION * @initial_velocity.abs / @physical_coeff)
      decel_minus_one = DECELERATION_RATE - 1.0
      (1000.0 * Math.exp(l / decel_minus_one)).to_i
    end

    def calc
      @elapsed_time += 16 # 毎回16ms経過

      return 0 if @elapsed_time > @duration

      t = @elapsed_time.to_f / @duration
      distance_coef = interpolate_spline_position(t)
      @current_velocity = interpolate_spline_velocity(t)

      # 現在の位置を計算
      @current_position = (distance_coef * @distance).to_i

      # 16ms前の位置からのdeltaを計算
      delta_position = @current_position - @previous_position

      # 現在の位置を次回のために保存
      @previous_position = @current_position

      delta_position
    end

    private

    def build_spline_tables
      (0...NB_SAMPLES).each do |i|
        alpha = i.to_f / NB_SAMPLES
        # x 方向のスプライン補間
        x_min = 0.0
        x_max = 1.0
        while true
          x = (x_min + x_max) / 2.0
          coef = 3.0 * x * (1.0 - x)
          tx = coef * ((1.0 - x) * P1 + x * P2) + x**3
          break if (tx - alpha).abs < 1e-5
          tx > alpha ? x_max = x : x_min = x
        end
        @spline_position[i] = coef * ((1.0 - x) * START_TENSION + x) + x**3

        # y 方向のスプライン補間
        y_min = 0.0
        y_max = 1.0
        while true
          y = (y_min + y_max) / 2.0
          coef = 3.0 * y * (1.0 - y)
          dy = coef * ((1.0 - y) * START_TENSION + y) + y**3
          break if (dy - alpha).abs < 1e-5
          dy > alpha ? y_max = y : y_min = y
        end
        @spline_time[i] = coef * ((1.0 - y) * P1 + y * P2) + y**3
      end
      @spline_position[NB_SAMPLES] = @spline_time[NB_SAMPLES] = 1.0
    end

    def interpolate_spline_position(t)
      index = (NB_SAMPLES * t).to_i
      return 1.0 if index >= NB_SAMPLES

      t_inf = index.to_f / NB_SAMPLES
      t_sup = (index + 1).to_f / NB_SAMPLES
      d_inf = @spline_position[index]
      d_sup = @spline_position[index + 1]
      velocity_coef = (d_sup - d_inf) / (t_sup - t_inf)
      d_inf + (t - t_inf) * velocity_coef
    end

    def interpolate_spline_velocity(t)
      index = (NB_SAMPLES * t).to_i
      return 0.0 if index >= NB_SAMPLES

      t_inf = index.to_f / NB_SAMPLES
      t_sup = (index + 1).to_f / NB_SAMPLES
      d_inf = @spline_position[index]
      d_sup = @spline_position[index + 1]
      velocity_coef = (d_sup - d_inf) / (t_sup - t_inf)
      velocity_coef * @distance / @duration * 1000.0
    end
  end
end
