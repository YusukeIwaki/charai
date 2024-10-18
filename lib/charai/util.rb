module Charai
  class Util
    def self.macos?
      RUBY_PLATFORM =~ /darwin/
    end

    def self.linux?
      RUBY_PLATFORM =~ /linux/
    end
  end
end
