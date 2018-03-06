module Suspenders
  class ViewsGenerator < Rails::Generators::Base
    def create_shared_javascripts
      copy_file "_javascript.html.erb",
        "app/views/application/_javascript.html.erb"
      copy_file "application_rollbar_js.html.erb",
        "app/views/application/_rollbar_js.html.erb"
    end
  end
end
