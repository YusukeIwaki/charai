[![Gem Version](https://badge.fury.io/rb/charai.svg)](https://badge.fury.io/rb/charai)


# Charai

Chat + Ruby + AI = Charai

Charai is an AI-powered Capybara driver that enables natural language web testing. Write your E2E tests by describing what you want to test in plain language, and let AI handle the browser interactions.

## Requirements

- Ruby 2.7 or higher
- Firefox Developer Edition
- OpenAI API key or compatible AI service (Azure OpenAI, Gemini, Ollama)

## Setup

Add `gem 'charai'` into your project's Gemfile, and then `bundle install`

Also, this gem requires **Firefox Developer Edition** to be installed on the location below:

- /Applications/Firefox Developer Edition.app (macOS)
- /usr/bin/firefox-devedition (Linux)

## Configuration

Configure your Capybara driver like below.

```
Capybara.register_driver :charai do |app|
  Charai::Driver.new(app, openai_configuration: config)
end

Capybara.register_driver :charai_headless do |app|
  Charai::Driver.new(app, openai_configuration: config, headless: true)
end
```

Please note that this driver required OpenAI service.

### OpenAI

```
config = Charai::OpenaiConfiguration.new(
  model: 'gpt-4o',
  api_key: 'sk-xxxxxxxxxxx'
)
```

### Azure OpenAI (Recommended)

```ruby
config = Charai::AzureOpenaiConfiguration.new(
  endpoint_url: 'https://YOUR-APP.openai.azure.com/openai/deployments/gpt-4o/chat/completions?api-version=2024-05-01-preview',
  api_key: 'aabbcc00112233445566'
)
```

**⚠️ Important Note for Azure OpenAI Environment Variables:**

When setting the endpoint URL via environment variables, you must include the full path with `/deployments/{model}/chat/completions`:

```bash
# ❌ This will NOT work
export AZURE_OPENAI_ENDPOINT_URL="https://your-resource.cognitiveservices.azure.com/openai/responses?api-version=2025-04-01-preview"

# ✅ This works correctly
export AZURE_OPENAI_ENDPOINT_URL="https://your-resource.cognitiveservices.azure.com/openai/deployments/gpt-4o-mini/chat/completions?api-version=2025-04-01-preview"
```

The endpoint URL must specify:
1. Your Azure resource endpoint
2. The deployment name (e.g., `gpt-4o-mini`, `gpt-4o`)
3. The `/chat/completions` path
4. The API version parameter

### Gemini

```ruby
config = Charai::GeminiOpenaiConfiguration.new(
  model: 'gemini-2.0-flash-exp',
  api_key: 'your-gemini-api-key'
)
```

### Ollama (Local AI)

```ruby
config = Charai::OllamaConfiguration.new(
  endpoint_url: 'http://localhost:11434',
  model: 'llama3.2'
)
```

## Usage

### Basic Example

```ruby
RSpec.describe "Login test", type: :feature do
  before do
    Capybara.current_driver = :charai
  end

  it "should login successfully" do
    page.driver << <<~MARKDOWN
    * Navigate to the login page
    * Enter "user@example.com" in the email field
    * Enter "password123" in the password field
    * Click the login button
    * Verify that you're redirected to the dashboard page
    * Check that the username "John Doe" is displayed in the header
    MARKDOWN
  end
end
```

### Advanced Example with Instructions

You can provide additional context about your application to help the AI better understand the page structure:

```ruby
before do
  Capybara.current_driver    = :charai
  Capybara.javascript_driver = :charai

  page.driver.additional_instruction = <<~MARKDOWN
  * このページは、3ペイン構造です。ユーザが仕事を探すためのページです。
  * 左ペインには仕事の絞り込みができるフィルター、中央ペインが仕事（求人）の一覧で、30件ずつ表示されます。
  * 左ペインにマウスを置いてスクロールしても、中央ペインはスクロールされません。一覧をスクロールしたいときには、中央ペインの座標を確認し、その中央にマウスを置いてスクロールしてください。
  * 右ペインは、広告エリアです。検索条件に応じた広告が表示されます。
  MARKDOWN
end

it 'should work' do
  page.driver << <<~MARKDOWN
  * 仕事の一覧が表示されたら、左ペインでサーバーサイドエンジニアで「Ruby on Rails」の仕事に絞り込みをしてください。
  * 左ペインで絞り込んだら、中央ペインにRuby on Railsに関する仕事が表示されていることを確認してください。
  * Ruby on Railsに関係のない仕事が、検索結果件数の半分以上あるばあいには、このテスト「検索結果不適合」として失敗としてください。
  MARKDOWN
end
```

### Report for long-running E2E tests

We often trigger E2E test during the night since it costs a lot of time. It is really boring to sit down in front of the PC during E2E testing.

This driver provides an extension (callback) feature for reporting.

First, let's prepare a report formatter like this.

```ruby
class HtmlReport
  def initialize
    @content = []
  end

  def start(introduction)
    @content << <<~HTML
    <html>
    <head><link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/mini.css/3.0.1/mini-default.min.css"></head>
    <body>
    <pre style="margin: 100px 75px; border-left: 0px;">#{introduction}</pre>
    HTML
  end

  def add_conversation(content, answer)
    if content.is_a?(Array)
      text = content.find { |c| c[:type] == 'text' }[:text]

      @content << <<~HTML
      <div style="margin: 40px 25px" class="card fluid">
      <h4 style="border-left: .25rem solid var(--pre-color);">user</h4>
      <pre>#{text}</pre>
      HTML

      content.each do |c|
        next unless c[:type] == 'image_url'

        @content << <<~HTML
        <img src="#{c[:image_url][:url]}" width="480" />
        HTML
      end

      @content << <<~HTML
      <h4 style="text-align: end; border-right: .25rem solid var(--pre-color);">assistant</h4>
      <pre style="border-left: 0px; border-right: .25rem solid var(--pre-color);">#{answer}</pre>
      </div>
      HTML
    else
      @content << <<~HTML
      <div style="margin: 40px 25px" class="card fluid">
      <h4 style="border-left: .25rem solid var(--pre-color);">user</h4>
      <pre>#{content}</pre>

      <h4 style="text-align: end; border-right: .25rem solid var(--pre-color);">assistant</h4>
      <pre style="border-left: 0px; border-right: .25rem solid var(--pre-color);">#{answer}</pre>
      </div>
      HTML
    end
  end

  def to_html
    @content << "</body></html>"
    @content.join("\n")
  end
end
```

and then configure a callback for recording test-results into the report. It would be a good choice to use Allure reports's attachment feature for this.

```ruby
config.around(:each, type: :feature) do |example|
  report = HtmlReport.new
  Capybara.current_session.driver.callback = {
    on_chat_start: -> (introduction) {
      report.start(introduction)
    },
    on_chat_conversation: ->(content_hash, answer) {
      puts answer
      report.add_conversation(content_hash, answer)
    },
  }

  example.run

  Allure.add_attachment(
    name: "Chat Report",
    source: report.to_html,
    type: 'text/html',
  )
end
```

With this report, we can check evidences for each test and investigate failed tests (postmortem).

## Troubleshooting

### Firefox Developer Edition not found

Make sure Firefox Developer Edition is installed in the correct location:
- macOS: `/Applications/Firefox Developer Edition.app`
- Linux: `/usr/bin/firefox-devedition`

You can also set a custom path:
```ruby
Charai::Driver.new(app,
  openai_configuration: config,
  firefox_path: '/path/to/firefox-dev'
)
```

### AI not understanding the page

Provide more context using `additional_instruction`:
```ruby
page.driver.additional_instruction = <<~MARKDOWN
  * This is a single-page application (SPA)
  * Wait for elements to load before interacting
  * The main navigation is in a hamburger menu on mobile
MARKDOWN
```

### Tests running slowly

Consider using a faster AI model or running in headless mode:
```ruby
Capybara.current_driver = :charai_headless
```

## Links

- [GitHub Repository](https://github.com/YusukeIwaki/charai)
- [RubyGems Page](https://rubygems.org/gems/charai)
- [Report Issues](https://github.com/YusukeIwaki/charai/issues)

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
