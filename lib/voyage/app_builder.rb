module Suspenders
  class AppBuilder < Rails::AppBuilder
    include Suspenders::Actions

    def agree?(prompt)
      puts prompt
      response = STDIN.gets.chomp

      response.empty? || %w(y yes).include?(response.downcase.strip)
    end

    def accept_defaults
      if agree?('Would you like to accept all defaults? [slim, devise w/ first & last name] (Y/n)')
        @@accept_defaults = true
      else
        @@accept_defaults = false
      end
    end

    def update_gemset_in_gemfile
      replace_in_file 'Gemfile', '#ruby-gemset', "#ruby-gemset=#{app_name}"

      # Remove commented out lines from template
      gsub_file('Gemfile', /^\s{2}\n/, '')
    end

    def bundle_without_production
      template '../templates/bundle_config', '.bundle/config'
    end

    def use_slim
      if @@accept_defaults || agree?('Would you like to use slim? (Y/n)')
        @@use_slim = true
        run 'gem install html2slim'
        update_application_rb_for_slim
      else
        @@use_slim = false
        gsub_file('Gemfile', /^gem 'slim-rails'\n/, '')
      end
    end

    def update_application_layout_for_slim
      find = <<-RUBY.gsub(/^ {4}/, '')
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

      inside('lib') do # arbitrary, run in context of newly generated app
        run "erb2slim '../app/views/layouts' '../app/views/layouts'"
        run "erb2slim -d '../app/views/layouts'"
      end

      # strip trailing space after closing "> in application layout before
      # trying to find and replace it
      replace_in_file 'app/views/layouts/application.html.slim', '| "> ', '| ">'

      find = <<-RUBY.gsub(/^ {6}/, '')
        |  <body class="
        = devise_controller? ? 'devise' : 'application'
        = body_class
        | ">
      RUBY

      replace = <<-RUBY.gsub(/^ {6}/, '')
        body class="\#{devise_controller? ? 'devise' : 'application'} \#{body_class}"
      RUBY

      replace_in_file 'app/views/layouts/application.html.slim', find, replace
    end

    def update_application_rb_for_slim
      inject_into_file "config/application.rb", after: "     g.fixture_replacement :factory_bot, dir: 'spec/factories'\n" do <<-'RUBY'.gsub(/^ {2}/, '')
        g.template_engine :slim
        RUBY
      end
    end

    # ------------
    # DEVISE SETUP
    # ------------
    def install_devise
      if @@accept_defaults || agree?('Would you like to install Devise? (Y/n)')
        @@use_devise = true

        if @@accept_defaults || agree?('Would you like to install Devise token authentication? (Y/n)')
          devise_token_auth = true
        end

        bundle_command 'exec rails generate devise:install'

        if @@accept_defaults || agree?("Would you like to add first_name and last_name to the devise model? (Y/n)")
          adding_first_and_last_name = true

          bundle_command "exec rails generate resource user first_name:string last_name:string uuid:string"

          replace_in_file 'spec/factories/users.rb',
            'first_name "MyString"', 'first_name { Faker::Name.first_name }'
          replace_in_file 'spec/factories/users.rb',
            'last_name "MyString"', 'last_name { Faker::Name.last_name }'
          replace_in_file 'spec/factories/users.rb',
            'uuid "MyString"', 'uuid { SecureRandom.uuid }'
        end

        bundle_command "exec rails generate devise user"
        bundle_command 'exec rails generate devise:views'
        remove_password_fields_from_views

        if @@use_slim
          inside('lib') do # arbitrary, run in context of newly generated app
            run "erb2slim '../app/views/devise' '../app/views/devise'"
            run "erb2slim -d '../app/views/devise'"
          end
        end

        customize_devise_views if adding_first_and_last_name
        customize_application_controller_for_devise(adding_first_and_last_name)
        add_devise_registrations_controller
        customize_resource_controller_for_devise(adding_first_and_last_name)
        add_admin_views_for_devise_resource(adding_first_and_last_name)
        add_analytics_initializer
        authorize_devise_resource_for_index_action
        add_canard_roles_to_devise_resource
        update_devise_initializer(devise_token_auth)
        add_devise_invitable
        add_custom_routes_for_devise
        customize_user_factory(adding_first_and_last_name)
        generate_seeder_templates(using_devise: true)
        customize_user_spec
        add_token_auth if devise_token_auth
      else
        @@use_devise = false
        generate_seeder_templates(using_devise: false)
      end
    end

    def remove_password_fields_from_views
      gsub_file 'app/views/devise/registrations/edit.html.erb',
        '<%= f.input :password, autocomplete: "off", hint: "leave it blank if you don\'t want to change it", required: false %>',
        ''

      gsub_file 'app/views/devise/registrations/edit.html.erb',
        '<%= f.input :password_confirmation, required: false %>',
        ''

      gsub_file 'app/views/devise/registrations/edit.html.erb',
        '<%= f.input :current_password, hint: "we need your current password to confirm your changes", required: true %>',
        ''

      inject_into_file 'app/views/devise/registrations/edit.html.erb',
        after: '<div class="form-inputs">' do <<-RUBY.gsub(/^ {8}/, '')

        <% if @user.photo.present? %>
          <%= image_tag @user.photo.url, style: 'max-width: 120px; max-height: 120px;' %>
        <% end %>
        <%= f.input :photo, as: :hidden, input_html: {value: @user.cached_photo_data} %>
        <%= f.input :photo, as: :file %>
      RUBY
      end
    end

    def customize_devise_views
      %w(edit new).each do |file|
        if @@use_slim
          file_path = "app/views/devise/registrations/#{file}.html.slim"
          inject_into_file file_path, before: "    = f.input :email, required: true, autofocus: true" do <<-'RUBY'.gsub(/^ {8}/, '')
            = f.input :first_name, required: true, autofocus: true
            = f.input :last_name, required: true
            RUBY
          end
        else
          file_path = "app/views/devise/registrations/#{file}.html.erb"
          inject_into_file file_path, before: "    <%= f.input :email, required: true, autofocus: true %>" do <<-'RUBY'.gsub(/^ {8}/, '')
            <%= f.input :first_name, required: true, autofocus: true %>
            <%= f.input :last_name, required: true %>
            RUBY
          end
        end
      end
    end

    def customize_application_controller_for_devise(adding_first_and_last_name)
      inject_into_file 'app/controllers/application_controller.rb', before: "class ApplicationController < ActionController::Base" do <<-RUBY.gsub(/^ {8}/, '')
        # rubocop:disable Metrics/ClassLength, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/LineLength
        RUBY
      end

      inject_into_file 'app/controllers/application_controller.rb', after: "  protect_from_forgery with: :exception" do <<-RUBY.gsub(/^ {6}/, '')

        include AnalyticsTrack
        check_authorization unless: :devise_or_pages_controller?
        impersonates :user

        before_action :configure_permitted_parameters, if: :devise_controller?
        before_action :authenticate_user!, unless: -> { is_a?(HighVoltage::PagesController) }
        before_action :add_layout_name_to_gon
        before_action :detect_device_type

        rescue_from CanCan::AccessDenied do |exception|
          Rails.logger.error "Access denied on \#{exception.action} \#{exception.subject.inspect}"

          redirect_to '/unauthorized', alert: exception.message
        end

        protected

        def devise_or_pages_controller?
          devise_controller? == true || is_a?(HighVoltage::PagesController)
        end

        def configure_permitted_parameters
          devise_parameter_sanitizer.permit(
            :sign_up,
            keys: [
              #{':first_name,' if adding_first_and_last_name}
              #{':last_name,' if adding_first_and_last_name}
              :email,
              :photo,
              :password,
              :password_confirmation,
              :remember_me,
            ],
          )

          devise_parameter_sanitizer.permit(
            :sign_in,
            keys: [
              :login, :email, :password, :remember_me
            ],
          )

          devise_parameter_sanitizer.permit(
            :account_update,
            keys: [
              #{':first_name,' if adding_first_and_last_name}
              #{':last_name,' if adding_first_and_last_name}
              :email,
              :photo,
              :password,
              :password_confirmation,
              :current_password,
            ],
          )
        end

        def add_layout_name_to_gon
          gon.layout =
            case devise_controller?
            when true
              'devise'
            else
              'application'
            end
        end

        def detect_device_type
          request.variant =
            case request.user_agent
            when /iPad/i
              :tablet
            when /iPhone/i
              :phone
            when /Android/i && /mobile/i
              :phone
            when /Android/i
              :tablet
            when /Windows Phone/i
              :phone
            end
        end
        RUBY
      end
    end

    def add_devise_registrations_controller
      template '../templates/devise_registrations_controller.rb',
               'app/controllers/devise_customizations/registrations_controller.rb'
    end


    def add_analytics_initializer
      template '../templates/analytics_ruby_initializer.rb', 'config/initializers/analytics_ruby.rb'
      template '../templates/analytics_alias.html.erb.erb', 'app/views/users/analytics_alias.html.erb'
    end

    def customize_resource_controller_for_devise(adding_first_and_last_name)
      bundle_command 'exec rails generate controller users'
      run 'rm spec/controllers/users_controller_spec.rb'

      inject_into_class 'app/controllers/users_controller.rb', 'UsersController' do <<-RUBY.gsub(/^ {6}/, '')
        # https://github.com/CanCanCommunity/cancancan/wiki/authorizing-controller-actions
        # load_and_authorize_resource only: []
        skip_authorization_check only: [:analytics_alias,
                                        :edit_password,
                                        :update_password]

        def analytics_alias
          # view file has JS that will identify the anonymous user through segment
          # after registration via "after devise registration path"
        end

        def edit_password
          @user = User.find(current_user.id)
        end

        def update_password
          @user = User.find(current_user.id)
          if @user.update_with_password(user_params)
            # Sign in the user by passing validation in case their password changed
            bypass_sign_in(@user) unless true_user && true_user != @user
            flash[:notice] = 'Password successfully updated.'
            redirect_to root_path
          else
            # flash.now[:error] = 'Password not updated'
            render 'edit_password'
          end
        end

        private

        def user_params
          params.require(:user).permit(:password,
                                      :password_confirmation,
                                      :current_password)
        end
        RUBY

      end
      template '../templates/edit_password.html.slim', 'app/views/users/edit_password.html.slim'
    end

    def add_admin_views_for_devise_resource(adding_first_and_last_name)
      if @@use_slim
        inside('lib') do # arbitrary, run in context of newly generated app
          run "erb2slim '../app/views/users' '../app/views/users'"
          run "erb2slim -d '../app/views/users'"

          run "erb2slim '../app/views/admin/users' '../app/views/admin/users'"
          run "erb2slim -d '../app/views/admin/users'"
        end
      end

      # Later on, we customize the admin/users_controller around administrate (in add_administrate method)
    end

    def authorize_devise_resource_for_index_action
      generate 'canard:ability user can:manage:user cannot:destroy:user'
      generate 'canard:ability admin can:destroy:user'

      %w(admins users).each do |resource_name|
        replace_in_file "spec/abilities/#{resource_name}_spec.rb", "require 'cancan/matchers'", "require_relative '../support/matchers/custom_cancan'"
      end

      inject_into_file 'app/abilities/admins.rb', after: 'can [:destroy], User' do <<-RUBY.gsub(/^ {6}/, '')

        can :manage, :all
      RUBY
      end

      find = <<-RUBY.gsub(/^ {4}/, '')
        it { is_expected.to be_able_to(:manage, user) }
      RUBY
      replace = <<-RUBY.gsub(/^ {4}/, '')
        it { is_expected.to be_able_to(:manage, acting_user) }
        it { is_expected.to_not be_able_to(:manage, user) }
      RUBY
      replace_in_file 'spec/abilities/users_spec.rb', find, replace

      find = <<-RUBY.gsub(/^ {6}/, '')
        can [:manage], User
      RUBY
      replace = <<-RUBY.gsub(/^ {6}/, '')
        can [:manage], User do |u|
          u == user
        end
      RUBY
      replace_in_file 'app/abilities/users.rb', find, replace

      generate 'migration add_roles_mask_to_users roles_mask:integer'
      template '../templates/custom_cancan_matchers.rb', 'spec/support/matchers/custom_cancan.rb'
    end

    def add_canard_roles_to_devise_resource
      inject_into_file 'app/models/user.rb', before: /^end/ do <<-RUBY.gsub(/^ {6}/, '')

        before_create :generate_uuid

        # Permissions cascade/inherit through the roles listed below. The order of
        # this list is important, it should progress from least to most privelage
        ROLES = [:admin].freeze
        acts_as_user roles: ROLES
        roles ROLES

        validates :email,
                  presence: true,
                  format: /\\A[-a-z0-9_+\\.]+\\@([-a-z0-9]+\\.)+[a-z0-9]{2,8}\\z/i,
                  uniqueness: true

        # NOTE: these password validations won't run if the user has an invite token
        validates :password,
                  presence: true,
                  length: { within: 8..72 },
                  confirmation: true,
                  on: :create
        validates :password_confirmation,
                  presence: true,
                  on: :create
        PASSWORD_FORMAT_MESSAGE = 'Password must be between 8 and 72 characters'.freeze

        def tester?
          (email =~ /(example.com|headway.io)$/).present?
        end

        private

        def generate_uuid
          loop do
            uuid = SecureRandom.uuid
            self.uuid = uuid
            break unless User.exists?(uuid: uuid)
          end
        end
        RUBY
      end
    end

    def update_devise_initializer(devise_token_auth)
      replace_in_file 'config/initializers/devise.rb',
        'config.sign_out_via = :delete', 'config.sign_out_via = :get'

      if devise_token_auth
        replace_in_file 'config/initializers/devise.rb',
          '# config.http_authenticatable = false',
          'config.http_authenticatable = true'
      end

      replace_in_file 'config/initializers/devise.rb',
        "config.mailer_sender = 'please-change-me-at-config-initializers-devise@example.com'",
        "config.mailer_sender = 'user@example.com'"
    end

    def add_devise_invitable
      bundle_command 'exec rails generate devise_invitable:install'
      bundle_command 'exec rails generate devise_invitable User'

      file = Dir['db/migrate/*_devise_invitable_add_to_users.rb'].first
      replace_in_file file, 'class DeviseInvitableAddToUsers < ActiveRecord::Migration', 'class DeviseInvitableAddToUsers < ActiveRecord::Migration[4.2]'
    end

    def add_custom_routes_for_devise
      find = <<-RUBY.gsub(/^ {6}/, '')
        devise_for :users
        resources :users
      RUBY

      replace = <<-RUBY.gsub(/^ {6}/, '')
        devise_for :users, controllers: {
          registrations: 'devise_customizations/registrations',
          sessions: 'devise_customizations/sessions',
        }

        resources :users do
          member do
            get 'analytics_alias'
          end
          collection do
            get 'edit_password'
            patch 'update_password'
          end
        end

        namespace :admin do
          resources :users do
            member do
              get 'impersonate'
            end

            collection do
              get 'stop_impersonating'
            end
          end
        end

        authenticated :user do
          # root to: 'dashboard#show', as: :authenticated_root
          root to: 'high_voltage/pages#show', id: 'welcome', as: :authenticated_root
        end

        devise_scope :user do
          get 'sign-in',  to: 'devise/sessions#new'
          get 'sign-out', to: 'devise/sessions#destroy'
        end
      RUBY

      replace_in_file 'config/routes.rb', find, replace
    end

    def customize_user_factory(adding_first_and_last_name)
      inject_into_file 'spec/factories/users.rb', before: /^  end/ do <<-'RUBY'.gsub(/^ {4}/, '')
        password 'asdfjkl123'
        password_confirmation 'asdfjkl123'
        email { "user_#{uuid}@example.com" }

        trait :admin do
          roles [:admin]
          email { "admin_#{uuid}@example.com" }
        end
        RUBY
      end

      if adding_first_and_last_name
        inject_into_file 'spec/factories/users.rb', after: /roles \[:admin\]\n/ do <<-'RUBY'.gsub(/^ {4}/, '')
          first_name 'Admin'
          last_name 'User'
          RUBY
        end
      end
    end
    # ----------------
    # END DEVISE SETUP
    # ----------------

    def generate_seeder_templates(using_devise:)
      config = { force: true, using_devise: using_devise }
      template '../templates/lib/tasks/dev.rake.erb', 'lib/tasks/dev.rake', config
      template '../templates/seeds.rb.erb', 'db/seeds.rb', config
    end

    def customize_user_spec
      find = <<-RUBY.gsub(/^ {6}/, '')
        pending "add some examples to (or delete) \#{__FILE__}"
      RUBY

      replace = <<-RUBY.gsub(/^ {6}/, '')
        describe 'constants' do
          context 'roles' do
            it 'has the admin role' do
              expect(User::ROLES).to eq([:admin])
            end
          end
        end

        describe 'validations' do
          it { is_expected.to validate_presence_of(:email) }
          it { is_expected.to validate_presence_of(:password) }
          it { is_expected.to validate_presence_of(:password_confirmation) }
        end

        context '#tester?' do
          ['example.com', 'headway.io'].each do |domain|
            it "an email including the \#{domain} domain is a tester" do
              user = build(:user, email: "asdf@\#{domain}")
              expect(user.tester?).to eq(true)
            end
          end

          it 'an email including the gmail.com domain is NOT a tester' do
            user = build(:user, email: 'asdf@gmail.com')
            expect(user.tester?).to eq(false)
          end
        end

        context 'new user creation' do
          it 'ensures uniqueness of the uuid' do
            allow(User).to receive(:exists?).and_return(true, false)

            expect do
              create(:user)
            end.to change { User.count }.by(1)

            expect(User).to have_received(:exists?).exactly(2).times
          end
        end
      RUBY

      replace_in_file 'spec/models/user_spec.rb', find, replace
    end

    def add_token_auth
      generate 'model AuthenticationToken body:string user:references last_used_at:datetime ip_address:string user_agent:string'

      gsub_file 'app/models/user.rb',
        ':validatable',
        ':validatable, :token_authenticatable'

      inject_into_file 'app/models/user.rb', before: 'before_create :generate_uuid' do <<-RUBY.gsub(/^ {8}/, '')
        has_many :authentication_tokens

      RUBY
      end

      copy_file '../templates/devise_sessions_controller.rb', 'app/controllers/devise_customizations/sessions_controller.rb', force: true
    end

    def add_api_foundation
      # Create /app/api/base_api_controller.rb
      template '../templates/api_base_controller.rb', 'app/controllers/api/base_api_controller.rb', force: true

      # Create /app/api/v1/users_controller.rb
      template '../templates/api_users_controller.rb', 'app/controllers/api/v1/users_controller.rb', force: true

      # Create user resource
      copy_file '../templates/resources/api/v1/user_resource.rb', 'app/resources/api/v1/user_resource.rb', force: true

      # Setup JSONAPI::Resources
      copy_file '../templates/config_initializers_jsonapi_resources.rb', 'config/initializers/jsonapi_resources.rb', force: true

      # Update routes to include namespaced API
      inject_into_file 'config/routes.rb', before: /^end/ do <<-RUBY.gsub(/^ {6}/, '')

        # API-specific routes
        namespace 'api' do
          namespace 'v1' do
            resources :users, except: [:new, :edit]
          end
        end
        RUBY
      end

      template '../templates/config_initializers_ams.rb', 'config/initializers/ams.rb', force: true

      # Copy in API specs
      template '../templates/spec/support/database_cleaner.rb', 'spec/support/database_cleaner.rb', force: true
      template '../templates/spec/support/http_helpers.rb', 'spec/support/http_helpers.rb', force: true
      template '../templates/spec/requests/api/v1/users_controller_spec.rb', 'spec/requests/api/v1/users_controller_spec.rb', force: true
      template '../templates/spec/features/user_impersonation_spec.rb', 'spec/features/user_impersonation_spec.rb', force: true
      template '../templates/spec/features/user_list_spec.rb', 'spec/features/user_list_spec.rb', force: true
      template '../templates/spec/features/user_signup_spec.rb', 'spec/features/user_signup_spec.rb', force: true
      template '../templates/spec/support/api/schemas/user.json', 'spec/support/api/schemas/user.json', force: true

      template '../templates/spec/support/matchers/api_schema_matcher.rb', 'spec/support/matchers/api_schema_matcher.rb', force: true
      template '../templates/spec/support/matchers/json_api_matchers.rb', 'spec/support/matchers/json_api_matchers.rb', force: true
      template '../templates/spec/mailers/application_mailer_spec.rb.erb', 'spec/mailers/application_mailer_spec.rb', force: true
      template '../templates/spec/support/features/session_helpers.rb', 'spec/support/features/session_helpers.rb', force: true
      template '../templates/spec/support/request_spec_helper.rb', 'spec/support/request_spec_helper.rb', force: true
    end

    def add_administrate
      generate 'administrate:install'

      template '../templates/concerns_analytics_track.rb', 'app/controllers/concerns/analytics_track.rb', force: true

      # Setup admin/application_controller
      template '../templates/admin_application_controller.rb', 'app/controllers/admin/application_controller.rb', force: true

      # Setup administrate helper to allow hiding resources in the menu, and fix sorting parameters
      template '../templates/helpers/administrate_resources_helper.rb', 'app/helpers/administrate_resources_helper.rb', force: true
      template '../templates/helpers/admin/application_helper.rb', 'app/helpers/admin/application_helper.rb', force: true

      setup_trix_drag_and_drop
      setup_user_dashboard
      setup_roles_field

      copy_file '../templates/views/admin/users/_collection.html.erb', 'app/views/admin/users/_collection.html.erb', force: true
      copy_file '../templates/views/admin/users/index.html.erb', 'app/views/admin/users/index.html.erb', force: true
      copy_file '../templates/views/admin/users/_password_fields.html.slim', 'app/views/admin/users/_password_fields.html.slim', force: true

      generate 'administrate:views:edit'

      replace_in_file 'app/views/admin/application/_form.html.erb', 'form_for', "simple_form_for"
      copy_file '../templates/views/admin/application/_navigation.html.erb', 'app/views/admin/application/_navigation.html.erb', force: true

      inject_into_file 'config/initializers/simple_form.rb', after: 'SimpleForm.setup do |config|' do <<-RUBY

        SimpleForm::FormBuilder.map_type :inet, to: SimpleForm::Inputs::StringInput

      RUBY
      end
    end

    def setup_trix_drag_and_drop
      # Copy controller for receiving image uploads via JSON/XHR
      template '../templates/images_controller.rb', 'app/controllers/images_controller.rb', force: true

      # Setup Javascript for Trix drag-and-drop uploads
      generate 'administrate:assets:javascripts'
      copy_file '../templates/trix_attachments.js', 'app/assets/javascripts/administrate/components/trix_attachments.js', force: true

      inject_into_file 'app/abilities/users.rb', after: 'Canard::Abilities.for(:user) do' do <<-RUBY.gsub(/^ {6}/, '')

        can [:create], Image
      RUBY
      end

      inject_into_file 'config/routes.rb', before: 'namespace :admin do' do <<-RUBY
resources :images, only: [:create]

    RUBY
      end
    end

    def add_shrine
      template '../templates/config_initializers_shrine.rb', 'config/initializers/shrine.rb', force: true
      template '../templates/photo_uploader.rb', 'app/uploaders/photo_uploader.rb', force: true
      template '../templates/attachment_uploader.rb', 'app/uploaders/attachment_uploader.rb', force: true

      bundle_command "exec rails generate model image attachable:references{polymorphic} image_data:text"
      bundle_command "exec rails generate model attachment attachable:references{polymorphic} attachment_data:text"


      generate 'migration add_photo_to_users photo_data:string'

      inject_into_file 'app/models/user.rb', after: 'class User < ApplicationRecord' do <<-RUBY

      # adds an `photo` virtual attribute
      include ::PhotoUploader::Attachment.new(:photo)
        RUBY
      end

      inject_into_file 'app/models/image.rb', after: 'class Image < ApplicationRecord', force: true do <<-RUBY

      # adds an `image` virtual attribute
      include ::PhotoUploader::Attachment.new(:image)
        RUBY
      end

      # Remove association requirement for Trix uploading standalone Images
      gsub_file 'app/models/image.rb',
        'belongs_to :attachable, polymorphic: true',
        'belongs_to :attachable, polymorphic: true, required: false'

      inject_into_file 'app/models/attachment.rb', after: 'class Attachment < ApplicationRecord', force: true do <<-RUBY

      # adds an `photo` virtual attribute
      include ::AttachmentUploader::Attachment.new(:attachment)
        RUBY
      end
    end

    def add_address_model
      bundle_command "exec rails generate model address addressable:references{polymorphic} city:string line1:string line2:string state:string zip:string"

      inject_into_file 'app/models/address.rb', after: 'belongs_to :addressable, polymorphic: true', force: true do <<-RUBY

      validates :line1, :city, :state, :zip, presence: true
        RUBY
      end

      copy_file '../templates/concerns_address_fields.rb', 'app/models/concerns/address_fields.rb', force: true

      inject_into_file 'app/models/user.rb', after: 'acts_as_paranoid', force: true do <<-RUBY

      include AddressFields
        RUBY
      end
    end

    def add_paranoia_to_user
      generate 'migration add_deleted_at_to_users deleted_at:datetime:index'

      inject_into_file 'app/models/user.rb', after: 'class User < ApplicationRecord' do <<-RUBY

      acts_as_paranoid
        RUBY
      end
    end

    def setup_user_dashboard
      # Setup admin/users_controller

      generate 'administrate:views:edit User'

      template '../templates/admin_users_controller.rb', 'app/controllers/admin/users_controller.rb', force: true

      copy_file '../templates/views/admin/users/_role_edit.html.erb', 'app/views/admin/users/_role_edit.html.erb', force: true

      # Remove encrypted password field
      gsub_file 'app/dashboards/user_dashboard.rb',
        ':encrypted_password,',
        ''

      inject_into_file 'app/dashboards/user_dashboard.rb', after: 'ATTRIBUTE_TYPES = {' do <<-RUBY.gsub(/^ {8}/, '    ')
        roles: RolesField,
        password: Field::String,
        password_confirmation: Field::String,
        photo: Field::Shrine,
RUBY
      end

      inject_into_file 'app/dashboards/user_dashboard.rb', after: 'COLLECTION_ATTRIBUTES = [' do <<-RUBY.gsub(/^ {8}/, '    ')
        :roles,
        :photo,
RUBY
      end

      # By default, Thor ignores a further insertion of identical content, hence the force flag here
      inject_into_file 'app/dashboards/user_dashboard.rb', after: 'SHOW_PAGE_ATTRIBUTES = [', force: true do <<-RUBY.gsub(/^ {8}/, '    ')
        :roles,
        :photo,
RUBY
      end

      inject_into_file 'app/dashboards/user_dashboard.rb', after: 'FORM_ATTRIBUTES = [' do <<-RUBY.gsub(/^ {8}/, '    ')
        :roles,
        :password,
        :password_confirmation,
        :photo,
RUBY
      end

      inject_into_file 'config/routes.rb', after: 'namespace :admin do' do <<-RUBY.gsub(/^ {4}/, '')

        root to: 'users#index'
        RUBY
      end
      replace_in_file 'app/views/admin/users/_form.html.erb', 'form_for', "simple_form_for"

      inject_into_file 'app/views/admin/users/_form.html.erb', before: '<div class="form-actions">' do <<-RUBY.gsub(/^ {4}/, '')

        <%= render 'admin/users/role_edit', { f: f, user: page.resource, roles: User::ROLES } %>

        RUBY
      end
    end



    def setup_roles_field
      template '../templates/fields/roles_field.rb', 'app/fields/roles_field.rb', force: true

      copy_file '../templates/views/fields/roles_field/_form.html.erb', 'app/views/fields/roles_field/_form.html.erb', force: true
      copy_file '../templates/views/fields/roles_field/_index.html.erb', 'app/views/fields/roles_field/_index.html.erb', force: true
      copy_file '../templates/views/fields/roles_field/_show.html.erb', 'app/views/fields/roles_field/_show.html.erb', force: true
      inside('lib') do # arbitrary, run in context of newly generated app
        run "erb2slim '../app/views/fields' '../app/views/fields'"
        run "erb2slim -d '../app/views/fields'"
      end
    end

    def customize_application_js
      template '../templates/application.js', 'app/assets/javascripts/application.js', force: true

      template '../templates/app_name.js', "app/assets/javascripts/#{app_name}.js", force: true
      inject_into_file 'app/assets/javascripts/application.js', after: '//= require foundation' do <<-RUBY.gsub(/^ {8}/, '')

        //= require #{app_name}
      RUBY
      end

      inject_into_file 'app/views/application/_javascript.html.erb', after: '<%= render "analytics" %>' do <<-RUBY.gsub(/^ {8}/, '')

        <%= render "analytics_identify" %>
      RUBY
      end
    end

    def require_files_in_lib
      create_file 'config/initializers/require_files_in_lib.rb' do <<-RUBY.gsub(/^ {8}/, '')
        # rubocop:disable Rails/FilePath
        Dir[File.join(Rails.root, 'lib', '**', '*.rb')].each { |l| require l }
        # rubocop:enable Rails/FilePath
        RUBY
      end
    end

    def generate_ruby_version_and_gemset
      create_file '.ruby-gemset', "#{app_name}\n"
    end

    def generate_data_migrations
      generate 'data_migrations:install'

      file = Dir['db/migrate/*_create_data_migrations.rb'].first
      replace_in_file file, 'class CreateDataMigrations < ActiveRecord::Migration', "class CreateDataMigrations < ActiveRecord::Migration[4.2]"

      empty_directory_with_keep_file 'db/data_migrate'
    end

    def add_high_voltage_static_pages
      template '../templates/about.html.erb', "app/views/pages/about.html.#{@@use_slim ? 'slim' : 'erb'}"
      template '../templates/welcome.html.erb', "app/views/pages/welcome.html.erb"
      template '../templates/unauthorized.html.erb', "app/views/pages/unauthorized.html.#{@@use_slim ? 'slim' : 'erb'}"

      inject_into_file 'config/routes.rb', before: /^end/ do <<-RUBY.gsub(/^ {6}/, '')
        root 'high_voltage/pages#show', id: 'welcome'
        RUBY
      end

      create_file 'config/initializers/high_voltage.rb' do <<-RUBY.gsub(/^ {8}/, '')
        HighVoltage.configure do |config|
          config.route_drawer = HighVoltage::RouteDrawers::Root
        end
        RUBY
      end
    end

    def add_app_css_file
      bundle_command 'exec rails generate foundation:install --skip'
      bundle_command 'exec rails generate kaminari:views foundation'

      inject_into_file 'app/assets/stylesheets/foundation_and_overrides.scss', after: '@include foundation-top-bar;' do <<-RUBY.gsub(/^ {8}/, '')

        @include foundation-xy-grid-classes;
        RUBY
      end

      run 'rm -f app/views/layouts/foundation_layout.html.slim'

      create_file "app/assets/stylesheets/#{app_name}.scss" do <<-RUBY.gsub(/^ {8}/, '')
        //We can add some default styles here in voyage

        //Figure out what foundations visual grid settings are and turn them on here
        //$visual-grid: true;
        //$visual-grid-color: #9cf !default;
        //$visual-grid-index: front !default;
        //$visual-grid-opacity: 0.1 !default;
        .main { margin: 10px 30px; }

        a.active {
          background-color: rgba(220, 81, 72, 0.3);
        }
        RUBY
      end

      inject_into_file 'app/assets/stylesheets/application.scss', after: '@import "refills/flashes";'  do <<-RUBY.gsub(/^ {8}/, '')
        \n@import "#{app_name}";
        RUBY
      end
    end

    def add_navigation_and_footer
      template '../templates/navigation.html.erb', 'app/views/components/_navigation.html.erb', force: true
      template '../templates/footer.html.erb', 'app/views/components/_footer.html.erb', force: true
      inside('lib') do # arbitrary, run in context of newly generated app
        run "erb2slim '../app/views/components' '../app/views/components'"
        run "erb2slim -d '../app/views/components'"
      end
    end

    def generate_test_environment
      template '../templates/controller_helpers.rb', 'spec/support/controller_helpers.rb'
      template '../templates/simplecov.rb', '.simplecov'
    end

    def update_test_environment
      gsub_file 'spec/support/factory_bot.rb',
        'config.include FactoryGirl::Syntax::Methods',
        'config.include FactoryBot::Syntax::Methods'

      inject_into_file 'spec/support/factory_bot.rb', before: /^end/ do <<-RUBY.gsub(/^ {6}/, '')

        # Spring doesn't reload factory_bot
        config.before(:all) do
          FactoryBot.reload
        end
        RUBY
      end

      template "../templates/rails_helper.rb.erb", "spec/rails_helper.rb", force: true
    end

    def add_rubocop_config
      template '../templates/rubocop.yml', '.rubocop.yml', force: true
    end

    def add_auto_annotate_models_rake_task
      template '../templates/lib/tasks/auto_annotate_models.rake', 'lib/tasks/auto_annotate_models.rake', force: true
    end

    def add_favicon
      template '../templates/favicon.ico', 'app/assets/images/favicon.ico', force: true
    end

    def customize_application_mailer
      template '../templates/application_mailer.rb.erb', 'app/mailers/application_mailer.rb', force: true
    end

    def add_specs
      inject_into_file 'app/jobs/application_job.rb', before: "class ApplicationJob < ActiveJob::Base" do <<-RUBY.gsub(/^ {8}/, '')
        # :nocov:
        RUBY
      end

      template '../templates/spec/support/shared_examples/admin_dashboard_spec.rb', 'spec/support/shared_examples/admin_dashboard_spec.rb', force: true
      template '../templates/spec/controllers/admin/users_controller_spec.rb', 'spec/controllers/admin/users_controller_spec.rb', force: true
      template '../templates/spec/controllers/application_controller_spec.rb', 'spec/controllers/application_controller_spec.rb', force: true
    end

    # Do this last
    def rake_db_setup
      rake 'db:migrate'
      rake 'db:seed' if File.exist?('config/initializers/devise.rb')
    end

    def configure_rvm_prepend_bin_to_path
      run "rm -f $rvm_path/hooks/after_cd_bundler"

      run "touch $rvm_path/hooks/after_cd_bundler"

      git_safe_dir = <<-RUBY.gsub(/^ {8}/, '')
        #!/usr/bin/env bash
        export PATH=".git/safe/../../bin:$PATH"
        RUBY

      run "echo '#{git_safe_dir}' >> $rvm_path/hooks/after_cd_bundler"

      run 'chmod +x $rvm_path/hooks/after_cd_bundler'

      run 'mkdir -p .git/safe'
    end

    def configure_sidekiq
      template '../templates/Procfile', 'Procfile', force: true
      template '../templates/config_initializers_sidekiq.rb.erb', 'config/initializers/sidekiq.rb', force: true
      template '../templates/config_sidekiq.yml', 'config/sidekiq.yml', force: true

      sidekiq_config = <<-EOD
# Use Sidekiq for background job processing
  config.active_job.queue_adapter = :sidekiq
      EOD

      configure_environment('development', sidekiq_config)
      configure_environment('production', sidekiq_config)
    end

    def configure_letter_opener
      gsub_file 'config/environments/development.rb',
        'config.action_mailer.delivery_method = :file',
        'config.action_mailer.delivery_method = :letter_opener'
    end

    def configure_erd
      bundle_command 'exec rails generate erd:install'

      template '../templates/erdconfig.erb', '.erdconfig', force: true

      # Configure post-migration and -rollback hooks
      template '../templates/lib/tasks/post_migrate_hooks.rake', 'lib/tasks/post_migrate_hooks.rake', force: true
    end

    def run_rubocop_auto_correct
      run 'rubocop --auto-correct'
    end

    def copy_env_to_example
      run 'cp .env .env.example'
    end

    def add_to_gitignore
      inject_into_file '.gitignore', after: '/tmp/*' do <<-RUBY.gsub(/^ {8}/, '')

        .env
        .zenflow-log
        errors.err
        .ctags
        .cadre/coverage.vim
        /public/cuke_steps.html
        /public/uploads
        #{app_name}-erd.pdf
        RUBY
      end
    end

    ###############################
    # OVERRIDE SUSPENDERS METHODS #
    ###############################
    def configure_generators
      config = <<-RUBY.gsub(/^ {4}/, '')

        config.generators do |g|
          g.helper false
          g.javascript_engine false
          g.request_specs false
          g.routing_specs false
          g.stylesheets false
          g.serializer false
          g.test_framework :rspec
          g.view_specs false
          g.fixture_replacement :factory_bot, dir: 'spec/factories'
        end

      RUBY

      inject_into_class 'config/application.rb', 'Application', config
    end

    def set_ruby_to_version_being_used
      create_file '.ruby-version', "#{Voyage::RUBY_VERSION}\n"
    end

    def overwrite_application_layout
      template '../templates/voyage_layout.html.erb.erb', 'app/views/layouts/application.html.erb', force: true
      update_application_layout_for_slim if @@use_slim

      template '../templates/analytics_identify.html.erb.erb', 'app/views/application/_analytics_identify.html.erb', force: true
    end

    def create_database
      # Suspenders version also migrates, we don't want that yet... we migrate in the rake_db_setup method
      bundle_command 'exec rails db:create'
    end

    # --------------------------------
    # setup_test_environment overrides
    # --------------------------------

    # ------------------------------------
    # End setup_test_environment overrides
    # ------------------------------------

    def remove_config_comment_lines
      # NOTE: (2016-02-09) jonk => don't want this
    end

    def add_cucumber
      bundle_command 'exec rails generate cucumber:install'
      template "../templates/config_cucumber.yml", "config/cucumber.yml", force: true

      %w{ auth_steps cookies_steps date_time_steps debug_steps email_steps pickle_steps web_steps }.each do |file_name|
        template "../templates/cucumber/features/helper_steps/#{file_name}.rb", "features/step_definitions/helper_steps/#{file_name}.rb", force: true
      end

      %w{ cookies email env_local hooks pickle selectors cuke_steps env factory_bot paths pickle_dry_run }.each do |file_name|
        template "../templates/cucumber/features/support/#{file_name}.rb", "features/support/#{file_name}.rb", force: true
      end

    end
  end
end
