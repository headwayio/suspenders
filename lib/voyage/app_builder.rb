module Suspenders
  class AppBuilder < Rails::AppBuilder
    def application_js
      template '../templates/application.js', 'app/assets/javascripts/application.js', force: true
    end

    def application_controller
      template '../templates/application_controller.rb', 'app/controllers/application_controller.rb', force: true
    end

    def install_devise
      if yes?('Would you like to install Devise? (y/N)')
        bundle_command 'exec rails generate devise:install'

        model_name = ask('What would you like the user model to be called? [user]')
        model_name = 'user' if model_name.blank?

        if yes?("Would you like to add first_name and last_name to the devise model? (y/N)")
          adding_first_and_last_name = true
          bundle_command "exec rails generate scaffold #{model_name} first_name:string last_name:string"
        end

        bundle_command "exec rails generate devise #{model_name}"
        bundle_command 'exec rails generate devise:views'

        run 'gem install html2slim'
        inside('lib') do # arbitrary, run in context of newly generated app
          run "erb2slim '../app/views/devise' '../app/views/devise'"
          run "erb2slim -d '../app/views/devise'"
        end

        customize_devise_views if adding_first_and_last_name
      end
    end

    def customize_devise_views
      %w(edit new).each do |file|
        file_path = "app/views/devise/registrations/#{file}.html.slim"
        inject_into_file file_path, before: "    = f.input :email, required: true, autofocus: true" do <<-'RUBY'
    = f.input :first_name, required: true, autofocus: true
    = f.input :last_name, required: true
RUBY
        end
      end
    end

    def gemfile
      template '../templates/Gemfile.erb', 'Gemfile'
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
