module Suspenders
  class AppGenerator < Rails::Generators::AppGenerator
    class_option :skip_turbolinks, type: :boolean, default: false,
      desc: "Skip turbolinks gem"

    class_option :skip_bundle, type: :boolean, aliases: "-B", default: true,
      desc: "Don't run bundle install"

    def self.start
      preflight_check
      accept_defaults

      super
    end

    def self.preflight_check
      puts '"bundle install" will be run for the current ruby version and gemset. Press enter to continue...'
      prompt = STDIN.gets.chomp

      unless prompt.empty?
        puts "Skipping install. Please create a ruby gemset first!"
        exit 1
      end
    end

    def self.accept_defaults
      Suspenders::AppBuilder.new.accept_defaults
    end

    def finish_template
      invoke :suspenders_customization
      invoke :use_slim
      invoke :install_devise
      invoke :customize_application_js
      invoke :require_files_in_lib
      invoke :generate_date_time_formats
      invoke :generate_ruby_version_and_gemset
      invoke :generate_data_migrations
      invoke :add_high_voltage_static_pages
      invoke :generate_refills
      invoke :generate_test_environment
      invoke :update_test_environment


      # Do these last
      invoke :rake_db_setup
      invoke :configure_rvm_prepend_bin_to_path
      invoke :actually_setup_spring
      invoke :bon_voyage
      super
    end

    def use_slim
      build :use_slim
    end

    def install_devise
      build :install_devise
    end

    def customize_application_js
      build :customize_application_js
    end

    def require_files_in_lib
      build :require_files_in_lib
    end

    def generate_date_time_formats
      build :generate_date_time_formats
    end

    def generate_ruby_version_and_gemset
      build :generate_ruby_version_and_gemset
    end

    def generate_data_migrations
      build :generate_data_migrations
    end

    def add_high_voltage_static_pages
      build :add_high_voltage_static_pages
    end

    def rake_db_setup
      build :rake_db_setup
    end

    def generate_refills
      build :generate_refills
    end

    def generate_test_environment
      build :generate_test_environment
    end

    def update_test_environment
      build :update_test_environment
    end

    def configure_rvm_prepend_bin_to_path
      build :configure_rvm_prepend_bin_to_path
    end

    def setup_spring
      # do nothing so we can run generators after suspenders_customization runs
    end

    def actually_setup_spring
      say "Springifying binstubs"
      build :setup_spring
    end

    def outro
      # need this to be nothing so it doesn't output any text when
      # :suspenders_customization runs and it invokes this method
    end

    def bon_voyage
      say 'Congratulations! You just pulled our suspenders, Headway style!'
    end
  end
end
