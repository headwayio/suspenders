module Suspenders
  class AppGenerator < Rails::Generators::AppGenerator
    class_option :skip_turbolinks, type: :boolean, default: false,
      desc: "Skip turbolinks gem"

    class_option :skip_bundle, type: :boolean, aliases: "-B", default: false,
      desc: "Don't run bundle install"

    def finish_template
      invoke :suspenders_customization
      invoke :customize_application_js
      invoke :bon_voyage
      super
    end

    def customize_application_js
      build :application_js
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
