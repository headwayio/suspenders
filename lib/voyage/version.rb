module Voyage
  RAILS_VERSION = "~> 4.2".freeze
  RUBY_VERSION =
    IO
      .read("#{File.dirname(__FILE__)}/../../.ruby-version")
      .strip
      .freeze
  VERSION = '1.1'.freeze
end
