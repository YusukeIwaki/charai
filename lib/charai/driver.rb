# frozen_string_literal: true

module Charai
  class Driver < ::Capybara::Driver::Base
    class << self
      # global browser instance
      attr_accessor :__browser
    end

    def initialize(_app, **options)
      @headless = options[:headless]
      @debug_protocol = %w[1 true].include?(ENV['DEBUG'])
      @debug_openai_chat_message = @debug_protocol || %w[openai].include?(ENV['DEBUG'])
    end

    def wait?; false; end
    def needs_server?; true; end

    def <<(text)
      message = Agent::Message.new(text: text)
      agent.send_message_to_openai_chat(message)
    end

    def reset!
      @browsing_context&.close
      @browsing_context = nil
      @openai_chat&.clear
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
      Driver.__browser ||= Browser.launch(headless: @headless, debug_protocol: @debug_protocol)
    end

    def browsing_context
      @browsing_context ||= browser.create_browsing_context.tap do |context|
        context.set_viewport(width: 1280, height: 1024)
      end
    end

    def openai_chat
      @openai_chat ||= OpenaiChat.new(introduction: INTRODUCTION, debug_message: @debug_openai_chat_message)
    end

    def agent
      @agent ||= Agent.new(
        input_tool: InputTool.new(browsing_context),
        openai_chat: openai_chat,
      )
    end

    INTRODUCTION = <<~MARKDOWN
    あなたはWebサイトの試験が得意なテスターです。

    ブラウザを操作する方法は以下の内容です。

    * 画面の左上から (10ピクセル, 20ピクセル)の位置をクリックしたい場合には `driver.click(x: 10, y: 20)`
    * キーボードで "hogeHoge!!" と入力したい場合には `driver.type_text("hogeHoge!!")`
    * Enterキーを押したい場合には `driver.press_key("Enter")`
    * コピー＆ペーストをしたい場合には `driver.on_pressing_key("CtrlOrMeta") { driver.press_key("c") ; driver.press_key("v") }`
    * 画面の左上から (10ピクセル, 20ピクセル)の位置にマウスを置いてスクロール操作で下に向かってスクロールをしたい場合には `driver.scroll_down(x: 10, y: 20, velocity: 1000)`
    * 同様に、上に向かってスクロールをしたい場合には `driver.scroll_up(x: 10, y: 20, velocity: 1000)`
    * 画面が切り替わるまで2秒待ちたい場合には `driver.sleep_seconds(2)`
    * 現在の画面を一旦確認したい場合には `driver.capture_screenshot`
    * DOM要素の位置を確認するために、JavaScriptの実行結果を取得したい場合は `driver.execute_script('JSON.stringify(document.querySelector("#some").getBoundingClientRect())')`
    * テスト項目1がOKの場合には `driver.assertion_ok("テスト項目1")` 、テスト項目2がNGの場合には `driver.assertion_fail("テスト項目2")`

    例えば、class="login"のテキストボックスの場所を特定したい場合には

    ```
    driver.execute_script('JSON.stringify(document.querySelector("input.login").getBoundingClientRect())')
    ```

    そうすると、私が以下のように実行結果を返します。

    ```
    {"top":396.25,"right":638.4140625,"bottom":422.25,"left":488.4140625,"width":150,"height":26,"x":488.4140625,"y":396.25}
    ```

    これで、要素の真ん中をクリックしたい場合には `driver.click(x: 563, y: 409)` のように実行できます。

    また、画面の (100, 200) の位置にあるテキストボックスに"admin"というログイン名を入力して、その下のテキストボックスに "Passw0rd!" という文字列を入力して、Submitした結果、ログイン後のダッシュボード画面が表示されていることを確認する場合には、

    ```
    driver.click(x: 100, y: 200)
    driver.type_text("admin")
    driver.press_key("Tab")
    driver.type_text("Passw0rd!")
    driver.press_key("Enter")
    driver.sleep_seconds(2)
    driver.capture_screenshot
    ```

    のような指示だけを出力してください。 `driver.capture_screenshot` を呼ぶと、その後、私が画像をアップロードします。その画像を見て、ログイン画面のままであれば、再度上記のようなログイン手順を、ログインを完了できるように指示だけ出力してください。

    ```
    driver.click(x: 100, y: 320)
    driver.type_text("Passw0rd!")
    driver.press_key("Enter")
    driver.sleep_seconds(2)
    driver.capture_screenshot
    ```

    ログイン後のダッシュボード画面に遷移したと判断したら `driver.assertion_ok("ログイン後のダッシュボード画面に遷移すること")` のような指示だけ出力してください。5回やってもうまくいかない場合には `driver.assertion_fail("ログイン後のダッシュボード画面に遷移すること")` のような指示だけ出力してください。

    必ず、画像を見てクリックする場所がどこかを判断して `driver.click` を実行するようにしてください。場所がわからない場合には `driver.execute_script` を活用して、要素の場所を確認してください。 `driver.execute_script` を呼ぶと、私がJavaScriptの実行結果をアップロードします。現在のDOMの内容を確認したいときにも `driver.execute_script` は使用できます。例えば `driver.execute_script('document.body.innerHTML')` を実行すると現在のDOMのBodyのHTMLを取得することができます。

    何も変化がない場合には、正しい場所をクリックできていない可能性が高いです。その場合には上記のgetBoundingClientRectを使用する手順で、クリックする位置を必ず確かめてください。

    それでは始めます。テストしたい手順は以下の内容です。
    MARKDOWN
  end
end
