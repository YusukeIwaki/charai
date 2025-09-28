# AGENTS.md

This guide summarizes how autonomous coding agents should work in this repository. Use it alongside `CLAUDE.md` to keep behaviors consistent across toolchains.

## Project Overview

Charai is an AI-powered Capybara driver that turns natural language instructions into automated browser tests using OpenAI, Azure OpenAI, Gemini, or Ollama backends. When a scenario is described in markdown, the agent coordinates with Firefox Developer Edition to execute end-to-end flows.

## Development Commands

### Testing
- `bundle exec rspec` - Run the full test suite
- `bundle exec rspec spec/local/` - Local harness specs without external services
- `bundle exec rspec spec/web/` - Browser-driven integration specs
- `bundle exec rspec spec/charai/` - Unit coverage for internal components

### Code Quality
- `bundle exec rubocop` - Lint the codebase
- `bundle exec rubocop -a` - Auto-correct lint offences when appropriate

### Gem Management
- `bundle install` - Install Ruby dependencies
- `bundle exec rake build` - Build the gem artifact under `pkg/`
- `bundle exec rake install` - Install the gem locally
- `bundle exec rake release` - Publish a release (requires credentials)

### Development Setup
- Firefox Developer Edition must be available at:
  - macOS: `/Applications/Firefox Developer Edition.app`
  - Linux: `/usr/bin/firefox-devedition`
- Provide credentials for OpenAI-compatible services (Azure OpenAI, Gemini, Ollama) before running specs that exercise AI flows

## Architecture

### Core Components

**Driver (`lib/charai/driver.rb`)
- Registers the Capybara driver and manages session lifecycle
- Orchestrates browser startup, teardown, and AI message loops
- Supports both headless and headed execution

**Agent (`lib/charai/agent.rb`)
- Bridges AI chat responses and browser actions
- Executes AI-generated Ruby within a sandbox and queues follow-up work
- Aggregates RSpec failures when available to improve reporting

**Browser Stack**
- `browser.rb` encapsulates the running Firefox instance over WebDriver BiDi
- `browser_launcher.rb` bootstraps Firefox processes
- `browsing_context.rb` tracks tabs and viewport state
- `web_socket.rb` handles BiDi messaging

**AI Integration**
- `openai_chat.rb` manages chat completions across supported providers
- `openai_configuration.rb` normalizes API credentials and options
- `input_tool.rb` maps AI directives to concrete Capybara-style actions

### Key Patterns

1. **Natural Language Specs**: Tests stream markdown steps (`page.driver << markdown`) that the AI interprets.
2. **Callback Hooks**: Drivers can emit structured events for logging and reporting.
3. **Sandboxed Execution**: Ruby snippets from the AI run inside a guardrail that blocks shell escapes (like backticks).
4. **Pluggable Backends**: Swappable AI providers share the same configuration surface.

### Test Layout

- `spec/local/` for Sinatra harness scenarios without network dependencies
- `spec/web/` for real browser flows that need Firefox + AI credentials
- `spec/charai/` for unit-level coverage
- Allure reports accumulate under `reports/allure-results/`

### Configuration Samples

```ruby
# OpenAI
config = Charai::OpenaiConfiguration.new(model: "gpt-4o", api_key: "sk-...")

# Azure OpenAI
config = Charai::AzureOpenaiConfiguration.new(
  endpoint_url: "https://your-app.openai.azure.com/...",
  api_key: "your-key"
)

# Gemini
config = Charai::GeminiOpenaiConfiguration.new(model: "gemini-pro", api_key: "your-key")

# Ollama
config = Charai::OllamaConfiguration.new(endpoint_url: "http://localhost:11434", model: "llama2")
```

## Security Notes

- Do not attempt to execute shell commands via backticks or `%x`; the sandbox will block them and such attempts violate repository policy.
- Keep AI-exposed surfaces limited to vetted helper methods in the driver and input tool.
- Treat API keys and secrets as sensitive; never hardcode them in specs or fixtures.

## Agent Checklist

1. Install dependencies (`bundle install`) before running tests.
2. Reset Firefox Developer Edition if the driver cannot attach to a session.
3. Run targeted specs (`bundle exec rspec spec/local/`) after making changes to the driver or agent.
4. Run `bundle exec rubocop` before finalizing changes to ensure style compliance.
5. Validate that sandbox protections remain intact whenever modifying `agent.rb` or execution helpers.
