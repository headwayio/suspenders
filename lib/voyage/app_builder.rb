module Suspenders
  class AppBuilder < Rails::AppBuilder
    def application_js
      template "../templates/application.js", "app/assets/javascripts/application.js", force: true
    end

    def gemfile
      template "../templates/Gemfile.erb", "Gemfile"
    end

    def configure_generators
      config = <<-RUBY

    config.generators do |g|
      g.helper false
      g.javascript_engine false
      g.request_specs false
      g.routing_specs false
      g.stylesheets false
      g.test_framework :rspec
      g.view_specs false
      g.fixture_replacement :factory_girl, dir: 'spec/factories'
      g.template_engine :slim
    end

      RUBY

      inject_into_class 'config/application.rb', 'Application', config
    end

    def set_ruby_to_version_being_used
      create_file '.ruby-version', "#{Voyage::RUBY_VERSION}\n"
    end


    # --------------------------------
    # setup_test_environment overrides
    # --------------------------------
    def generate_factories_file
      # NOTE: (2016-02-03) jonk => don't want this
      # copy_file "factories.rb", "spec/factories.rb"
    end

    def configure_ci
      template "circle.yml.erb", "circle.yml"
    end

    def configure_background_jobs_for_rspec
      run 'rails g delayed_job:active_record'
    end

    def configure_capybara_webkit
      # NOTE: (2016-02-03) jonk => don't want this
      # copy_file "capybara_webkit.rb", "spec/support/capybara_webkit.rb"
    end
    # ------------------------------------
    # End setup_test_environment overrides
    # ------------------------------------


    # -------------
    # Configure App
    # -------------
    def configure_active_job
      configure_application_file(
        "config.active_job.queue_adapter = :delayed_job"
      )
      configure_environment "test", "config.active_job.queue_adapter = :inline"
    end

    def configure_puma
      # NOTE: (2016-02-03) jonk => don't want this
      # copy_file "puma.rb", "config/puma.rb"
    end

    def set_up_forego
      # NOTE: (2016-02-03) jonk => don't want this
      # copy_file "Procfile", "Procfile"
    end
    # -----------------
    # End Configure App
    # -----------------
  end
end
