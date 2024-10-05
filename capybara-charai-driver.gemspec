# frozen_string_literal: true

require_relative "lib/capybara/charai/driver/version"

Gem::Specification.new do |spec|
  spec.name = "capybara-charai-driver"
  spec.version = Capybara::Charai::Driver::VERSION
  spec.authors = ["YusukeIwaki"]
  spec.email = ["q7w8e9w8q7w8e9@yahoo.co.jp"]

  spec.summary = "charai(Chat + Ruby + AI) driver for Capybara"
  spec.description = "Prototype impl for Kaigi on Rails 2024 presentation."
  spec.homepage = "https://github.com/YusukeIwaki/capybara-charai-driver"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{^(test|spec|features)/}) || f.include?(".git")
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "concurrent-ruby", ">= 1.1.6"
end
