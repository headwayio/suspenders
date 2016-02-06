module Suspenders
  class AppGenerator < Rails::Generators::AppGenerator
    class_option :skip_turbolinks, type: :boolean, default: false,
      desc: "Skip turbolinks gem"

    class_option :skip_bundle, type: :boolean, aliases: "-B", default: true,
      desc: "Don't run bundle install"

    def self.start
      preflight_check

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

    def finish_template
      invoke :suspenders_customization
      invoke :customize_application_js
      invoke :generate_devise_install
      invoke :customize_application_controller
      invoke :actually_setup_spring
      invoke :bon_voyage
      super
    end

    def customize_application_js
      build :application_js
    end

    def customize_application_controller
      build :application_controller
    end

    def generate_devise_install
      build :install_devise
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