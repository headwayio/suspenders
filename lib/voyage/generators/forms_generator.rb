require "rails/generators"

module Suspenders
  class FormsGenerator < Rails::Generators::Base
    def configure_simple_form
      create_file "config/initializers/simple_form.rb" do
        "SimpleForm.setup {|config|}"
      end

      generate "simple_form:install", "--force --foundation"
    end
  end
end
