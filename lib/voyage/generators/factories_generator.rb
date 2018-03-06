require "rails/generators"

module Suspenders
  class FactoriesGenerator < Rails::Generators::Base
    def generate_empty_factories_file
      # Do nothing so factories generate in their own file
      # copy_file "factories.rb", "spec/factories.rb"
    end
  end
end
