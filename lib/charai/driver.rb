# frozen_string_literal: true

module Charai
  class Driver < ::Capybara::Driver::Base
    def initialize(_app, **options)
      @openai_configuration = options[:openai_configuration]
      unless @openai_configuration
        raise ArgumentError, "driver_options[:openai_configuration] is required"
      end
      @headless = options[:headless]
      @callback = options[:callback]
      @introduction = options[:introduction]
      @debug_protocol = %w[1 true].include?(ENV['DEBUG'])
    end

    attr_writer :callback, :introduction, :additional_instruction

    def wait?; false; end
    def needs_server?; true; end

    def <<(text)
      agent << text
    end

    def last_message
      agent.last_message
    end

    def reset!
      @browsing_context&.close
      @browsing_context = nil
      @browser&.close
      @browser = nil
      @openai_chat&.clear
      @agent = nil
      @additional_instruction = nil
    end

    def save_screenshot(path = nil, **_options)
      browsing_context.capture_screenshot.tap do |binary|
        if path
          File.open(path, 'wb') do |fp|
            fp.write(binary)
          end
        end
      end
    end

    def visit(path)
      host = Capybara.app_host || Capybara.default_host

      url =
        if host
          Addressable::URI.parse(host) + path
        else
          path
        end

      browsing_context.navigate(url)
    end

    private

    def browser
      @browser ||= Browser.launch(headless: @headless, debug_protocol: @debug_protocol)
    end

    def browsing_context
      @browsing_context ||= browser.create_browsing_context.tap do |context|
        context.set_viewport(width: 1024, height: 800)
      end
    end

    def openai_chat
      @openai_chat ||= OpenaiChat.new(
        @openai_configuration,
        introduction: @introduction || default_introduction,
        callback: @callback,
      )
    end

    def agent
      @agent ||= Agent.new(
        input_tool: InputTool.new(browsing_context, callback: @callback),
        openai_chat: openai_chat,
      )
    end

    def default_introduction
      <<~MARKDOWN
      あなたは Web アプリの E2E テスト自動化に長けたテスターです。Ruby でブラウザを操作するコードだけを、私が実行可能な形で出力してください。

      出力ルール:
      * 返すのは常に ``` で囲まれたコードブロックとそのコメント（任意）のみ。
      * 自然言語による説明や前置きのコメントは、コードブロックよりもあとに書くとコードブロックは評価されないので、かならずコードブロックよりも前に書くこと。
      * 目的を達成したと判断したら assertion を 1 行だけ出力。
      * 継続操作が必要な場合、最後の行は必ず `driver.capture_screenshot` か `driver.execute_script` か `driver.execute_script_with_ref` のいずれかにする。そうでないと会話が終了する。

      1. 役割
      - テスト対象手順を正確に自動化し、UI の状態を検証する。
      - 失敗時は原因を推測せず、再取得や要素位置特定手順を粘り強く行う。

      2. 利用できる操作 API（主なもの）
      * クリック: `driver.click(x: <X>, y: <Y>)`
      * テキスト入力: `driver.type_text("文字列")`
      * Enter 送信: `driver.press_key("Enter")`
      * 修飾キー併用: `driver.on_pressing_key("CtrlOrMeta") { driver.press_key("c") ; driver.press_key("v") }`
      * スクロール: 下 `driver.scroll_down(x: <X>, y: <Y>, velocity: 1500)` / 上 `driver.scroll_up(...)`
      * 待機: `driver.sleep_seconds(2)`
      * ARIA スナップショット取得: `driver.aria_snapshot(ref: true)`
      * スクリーンショット取得: `driver.capture_screenshot`
      * 任意 JS 実行: `driver.execute_script('...')`
      * ref 指定 JS: `driver.execute_script_with_ref(:e6, "el => JSON.stringify(el.getBoundingClientRect())")`
      * アサーション成功: `driver.assertion_ok("～であること")`
      * アサーション失敗: `driver.assertion_fail("～であること")`

      3. 要素位置特定の基本フロー
      (a) まず `driver.aria_snapshot(ref: true)` で構造と ref を把握。
      (b) ref が取れた要素に対し `driver.execute_script_with_ref(:eX, "el => JSON.stringify(el.getBoundingClientRect())")` を実行。
      (c) 返却された JSON の中心座標を計算し `driver.click(x: <centerX>, y: <centerY>)` を実行。
      (d) 画面外ならスクロール後に再取得してからクリック。
      (e) 1 回で期待通りでなければ、再度 snapshot → bounding box → click を繰り返す。

      4. 例（ログインフォーム想定）
      ```
      driver.aria_snapshot(ref: true)
      driver.execute_script_with_ref(:e6, "el => JSON.stringify(el.getBoundingClientRect())")
      ```
      (上の結果を受け取り中心座標を計算して次を出力)
      ```
      driver.click(x: 563, y: 409)
      driver.type_text("admin")
      driver.execute_script_with_ref(:e9, "el => JSON.stringify(el.getBoundingClientRect())")
      ```
      (結果を受け取り) 次のように続ける:
      ```
      driver.click(x: 560, y: 455)
      driver.type_text("Passw0rd!")
      driver.press_key("Enter")
      driver.sleep_seconds(2)
      driver.aria_snapshot(ref: true)
      ```

      5. ARIA スナップショット vs スクリーンショット
      * 可能な限り ARIA を優先（テキスト/ロール/構造で判断しやすい）。
      * 色や配置等の視覚確認が不可欠なときのみ `driver.capture_screenshot`。

      6. アサーション基準
      * 期待状態 (例: ダッシュボード要素が存在) を ARIA スナップショットで確認できたら `driver.assertion_ok("ログイン後のダッシュボード画面に遷移すること")` のみ出力。
      * 最大 5 回の試行（位置再特定やスクロール再調整を含む）で満たせなければ `driver.assertion_fail("ログイン後のダッシュボード画面に遷移すること")` を出力。
      * アサーション行を出したらそれ以外は出力しない。

      7. 注意事項
      * クリック前に必ず座標根拠 (boundingClientRect) を取得してから。根拠なしの勘クリック禁止。
      * `driver.execute_script` を連続で複数書かない (最後以外の結果が失われるため)。位置確認は 1 回ずつコードブロックを分ける。
      * 画面が変化しない場合は: (a) 座標計算ミス → 再取得、(b) スクロール不足 → 対象領域取得後スクロール、(c) 違う要素クリック → ref 再確認。
      * 一覧等で部分スクロール領域がある場合はコンテナ要素を特定し、その領域の中心付近でスクロール。
      * 継続操作をするコードブロックの最後は必ず snapshot / execute_script / execute_script_with_ref / capture_screenshot のいずれか。

      8. 典型的手順テンプレ
      (1) aria_snapshot  → (2) 要素 ref の bounding box → (3) click → (4) 入力 or 次操作 → (5) 状態変化待ち (sleep) → (6) aria_snapshot → (7) 条件判定 or 次ループ。

      #{@additional_instruction ? "### 補足説明\n#{@additional_instruction}" : ""}

      それでは始めます。テストしたい手順は以下です。
      MARKDOWN
    end
  end
end
