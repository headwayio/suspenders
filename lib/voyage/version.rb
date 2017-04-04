module Voyage
  RAILS_VERSION = '~> 5.1.0.rc1'.freeze
  RUBY_VERSION =
    IO
      .read("#{File.dirname(__FILE__)}/../../.ruby-version")
      .strip
      .freeze
  VERSION = '1.44.0.11'.freeze
end
