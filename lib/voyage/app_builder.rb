module Suspenders
  class AppBuilder < Rails::AppBuilder
    def agree?(prompt)
      puts prompt
      response = STDIN.gets.chomp

      response.empty? || %w(y yes).include?(response.downcase.strip)
    end

    def use_slim
      if agree?('Would you like to use slim? (Y/n)')
        @@use_slim = true
        run 'gem install html2slim'

        find = <<-RUBY.gsub(/^ {8}/, '')
          <%#
            Configure default and controller-, and view-specific titles in
            config/locales/en.yml. For more see:
            https://github.com/calebthompson/title#usage
          %>
        RUBY

        replace = <<-RUBY.gsub(/^ {8}/, '')
          <% # Configure default and controller-, and view-specific titles in
        # config/locales/en.yml. For more see:
        # https://github.com/calebthompson/title#usage %>
        RUBY

        replace_in_file 'app/views/layouts/application.html.erb', find, replace

        if @@use_slim
          inside('lib') do # arbitrary, run in context of newly generated app
            run "erb2slim '../app/views/layouts' '../app/views/layouts'"
            run "erb2slim -d '../app/views/layouts'"

            run "erb2slim '../app/views/application' '../app/views/application'"
            run "erb2slim -d '../app/views/application'"
          end
        end
      else
        @@use_slim = false
      end
    end

    # ------------
    # DEVISE SETUP
    # ------------
    def install_devise
      if agree?('Would you like to install Devise? (Y/n)')
        bundle_command 'exec rails generate devise:install'

        if agree?("Would you like to add first_name and last_name to the devise model? (Y/n)")
          adding_first_and_last_name = true

          bundle_command "exec rails generate resource user first_name:string last_name:string"

          replace_in_file 'spec/factories/users.rb',
            'first_name "MyString"', 'first_name { Faker::Name.first_name }'
          replace_in_file 'spec/factories/users.rb',
            'last_name "MyString"', 'last_name { Faker::Name.last_name }'

          inject_into_file 'spec/factories/users.rb', before: /^  end/ do <<-RUBY.gsub(/^ {8}/, '')
            password 'password'
            \n
            trait :admin do
              roles [:admin]
              first_name 'Admin'
              last_name 'User'
              sequence(:email) { |n| "admin_\#{n}@example.com" }
            end
            RUBY
          end
        end

        bundle_command "exec rails generate devise user"
        bundle_command 'exec rails generate devise:views'

        if @@use_slim
          inside('lib') do # arbitrary, run in context of newly generated app
            run "erb2slim '../app/views/devise' '../app/views/devise'"
            run "erb2slim -d '../app/views/devise'"
          end
        end

        customize_devise_views if adding_first_and_last_name
        customize_application_controller_for_devise(adding_first_and_last_name)
        customize_resource_controller_for_devise(adding_first_and_last_name)
        add_views_for_devise_resource(adding_first_and_last_name)
        add_root_definition_to_routes_for_devise_resource
        authorize_devise_resource_for_index_action
        add_canard_roles_to_devise_resource
        update_devise_initializer
        add_sign_in_and_sign_out_routes_for_devise
        generate_seeder_templates(using_devise: true)
      else
        generate_seeder_templates(using_devise: false)
      end
    end

    def customize_devise_views
      %w(edit new).each do |file|
        if @@use_slim
          file_path = "app/views/devise/registrations/#{file}.html.slim"
          inject_into_file file_path, before: "    = f.input :email, required: true, autofocus: true" do <<-'RUBY'.gsub(/^ {6}/, '')
            = f.input :first_name, required: true, autofocus: true
            = f.input :last_name, required: true
            RUBY
          end
        else
          file_path = "app/views/devise/registrations/#{file}.html.erb"
          inject_into_file file_path, before: "    <%= f.input :email, required: true, autofocus: true %>" do <<-'RUBY'.gsub(/^ {6}/, '')
            <%= f.input :first_name, required: true, autofocus: true %>
            <%= f.input :last_name, required: true %>
            RUBY
          end
        end
      end
    end

    def customize_application_controller_for_devise(adding_first_and_last_name)
      inject_into_file 'app/controllers/application_controller.rb', after: "  protect_from_forgery with: :exception" do <<-RUBY.gsub(/^ {6}/, '').gsub(/^ {8}\n/, '')
        \n
        before_action :configure_permitted_parameters, if: :devise_controller?

        protected

        def configure_permitted_parameters
          devise_parameter_sanitizer.for(:sign_up) do |u|
            u.permit(
              #{':first_name,' if adding_first_and_last_name}
              #{':last_name,' if adding_first_and_last_name}
              :email,
              :password,
              :password_confirmation,
              :remember_me,
            )
          end

          devise_parameter_sanitizer.for(:sign_in) do |u|
            u.permit(:login, :email, :password, :remember_me)
          end

          devise_parameter_sanitizer.for(:account_update) do |u|
            u.permit(
              #{':first_name,' if adding_first_and_last_name}
              #{':last_name,' if adding_first_and_last_name}
              :email,
              :password,
              :password_confirmation,
              :current_password,
            )
          end
        end
        RUBY
      end
    end

    def customize_resource_controller_for_devise(adding_first_and_last_name)
      bundle_command "exec rails generate controller users"

      inject_into_class "app/controllers/users_controller.rb", "UsersController" do <<-RUBY.gsub(/^ {6}/, '')
        # https://github.com/CanCanCommunity/cancancan/wiki/authorizing-controller-actions
        load_and_authorize_resource only: [:index, :show]
        RUBY
      end

      unless adding_first_and_last_name
        inject_into_file 'config/routes.rb', after: '  devise_for :users' do <<-RUBY.gsub(/^ {8}/, '')
          \n
          resources :#{controller_name}
          RUBY
        end
      end
    end

    def add_views_for_devise_resource(adding_first_and_last_name)
      config = { adding_first_and_last_name: adding_first_and_last_name }
      template '../templates/users_index.html.slim.erb', 'app/views/users/index.html.slim', config
    end

    def add_root_definition_to_routes_for_devise_resource
      inject_into_file 'config/routes.rb', before: /^end/ do <<-RUBY.gsub(/^ {6}/, '')
        root "users#index"
        RUBY
      end
    end

    def authorize_devise_resource_for_index_action
      generate "canard:ability user can:manage:user cannot:destroy:user"
      generate "canard:ability admin can:destroy:user"
      generate "migration add_roles_mask_to_users roles_mask:integer"
    end

    def add_canard_roles_to_devise_resource
      inject_into_file 'app/models/user.rb', before: /^end/ do <<-RUBY.gsub(/^ {6}/, '')
        \n
        # Permissions cascade/inherit through the roles listed below. The order of
        # this list is important, it should progress from least to most privelage
        ROLES = [:admin].freeze
        acts_as_user roles: ROLES
        roles ROLES
        RUBY
      end
    end

    def update_devise_initializer
      replace_in_file 'config/initializers/devise.rb',
        'config.sign_out_via = :delete', 'config.sign_out_via = :get'

      replace_in_file 'config/initializers/devise.rb',
        "config.mailer_sender = 'please-change-me-at-config-initializers-devise@example.com'",
        "config.mailer_sender = 'user@example.com'"
    end

    def add_sign_in_and_sign_out_routes_for_devise
      inject_into_file 'config/routes.rb', before: /^end/ do <<-RUBY.gsub(/^ {6}/, '')
        authenticated :user do
          # root to: 'dashboard#show', as: :authenticated_root
        end

        devise_scope :user do
          get 'sign-in',  to: 'devise/sessions#new'
          get 'sign-out', to: 'devise/sessions#destroy'
        end
        RUBY
      end
    end
    # ----------------
    # END DEVISE SETUP
    # ----------------

    def generate_seeder_templates(using_devise:)
      config = { force: true, using_devise: true }
      template '../templates/seeder.rb.erb', 'lib/seeder.rb', config
      template '../templates/seeds.rb.erb', 'db/seeds.rb', config
    end

    def customize_application_js
      template '../templates/application.js', 'app/assets/javascripts/application.js', force: true
    end

    def require_files_in_lib
      create_file 'config/initializers/require_files_in_lib.rb',
        "Dir[File.join(Rails.root, 'lib', '**', '*.rb')].each { |l| require l }\n"
    end

    def generate_date_time_formats
      template '../templates/date_time_formats.rb', 'config/initializers/date_time_formats.rb'
    end

    def generate_ruby_version_and_gemset
      create_file '.ruby-gemset', "#{app_name}\n"
    end

    def generate_data_migrations
      generate 'data_migrations:install'
    end

    def add_about_page_through_high_voltage
      template '../templates/about.html', "app/views/pages/about.html.#{@@use_slim ? 'slim' : 'erb'}"

      inject_into_file 'config/routes.rb', before: /^end/ do <<-RUBY.gsub(/^ {6}/, '')
        get '/about' => 'high_voltage/pages#about', id: 'about'
        RUBY
      end
    end

    # Do this last
    def rake_db_setup
      rake 'db:migrate'
      rake 'db:seed'
    end

    ###############################
    # OVERRIDE SUSPENDERS METHODS #
    ###############################

    def gemfile
      template '../templates/Gemfile.erb', 'Gemfile'
    end

    def configure_generators
      config = <<-RUBY.gsub(/^ {4}/, '')
        \n
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
        \n
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
