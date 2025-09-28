# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Charai is an AI-powered Capybara driver that enables natural language web testing using OpenAI/Gemini APIs. The name "Charai" comes from "Chat + Ruby + AI". This gem allows writing E2E tests by describing test scenarios in natural language, with the AI controlling browser interactions through Firefox Developer Edition.

## Development Commands

### Testing
- `bundle exec rspec` - Run all tests
- `bundle exec rspec spec/local/` - Run local tests (no web dependencies)
- `bundle exec rspec spec/web/` - Run web-based integration tests
- `bundle exec rspec spec/charai/` - Run unit tests for specific components

### Code Quality
- `bundle exec rubocop` - Run Ruby linter
- `bundle exec rubocop -a` - Auto-fix linting issues

### Gem Management
- `bundle install` - Install dependencies
- `bundle exec rake build` - Build the gem
- `bundle exec rake install` - Install gem locally
- `bundle exec rake release` - Release new version (requires proper credentials)

### Development Setup
- Requires **Firefox Developer Edition** installed at:
  - macOS: `/Applications/Firefox Developer Edition.app`
  - Linux: `/usr/bin/firefox-devedition`
- Requires OpenAI API key or compatible service (Azure OpenAI, Gemini, Ollama)

## Architecture

### Core Components

**Driver (`lib/charai/driver.rb`)**
- Main Capybara driver implementation
- Entry point for all interactions
- Manages browser lifecycle and AI chat sessions
- Supports headless and headed modes

**Agent (`lib/charai/agent.rb`)**
- Orchestrates communication between OpenAI chat and browser input
- Executes code blocks returned by AI in a sandboxed environment
- Handles error recovery and message queuing
- Uses RSpec failure aggregation when available

**Browser System**
- `Browser` - Manages Firefox browser instance via WebDriver BiDi protocol
- `BrowserLauncher` - Handles Firefox process startup
- `BrowsingContext` - Represents browser tab/window with viewport control
- `WebSocket` - Handles WebDriver BiDi communication

**AI Integration**
- `OpenaiChat` - Manages conversation with AI services
- `OpenaiConfiguration` - Supports OpenAI, Azure OpenAI, Gemini, and Ollama
- `InputTool` - Translates AI commands to browser actions (click, type, scroll, etc.)

### Key Patterns

1. **Natural Language Testing**: Tests are written as markdown descriptions that the AI interprets
2. **Callback System**: Supports reporting callbacks for test execution logging
3. **Sandboxed Execution**: AI-generated code runs in controlled environment with security restrictions
4. **Multi-Backend Support**: Configurable AI backends (OpenAI, Azure, Gemini, Ollama)

### Test Structure

- `spec/local/` - Tests that don't require external web services
- `spec/web/` - Integration tests using real websites
- `spec/charai/` - Unit tests for specific components
- Uses RSpec with Allure reporting integration

### Configuration Examples

The driver supports multiple AI backends:

```ruby
# OpenAI
config = Charai::OpenaiConfiguration.new(model: 'gpt-4o', api_key: 'sk-...')

# Azure OpenAI (Recommended)
config = Charai::AzureOpenaiConfiguration.new(
  endpoint_url: 'https://your-app.openai.azure.com/...',
  api_key: 'your-key'
)

# Gemini
config = Charai::GeminiOpenaiConfiguration.new(model: 'gemini-pro', api_key: 'your-key')

# Ollama
config = Charai::OllamaConfiguration.new(endpoint_url: 'http://localhost:11434', model: 'llama2')
```

## Security Notes

- The Agent class prevents shell command execution by blocking backticks
- AI-generated code runs in a restricted sandbox environment
- Only specific browser automation methods are exposed to the AI