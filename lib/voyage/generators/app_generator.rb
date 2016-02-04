module Voyage
  class AppGenerator < Suspenders::AppGenerator
    class_option :skip_turbolinks, type: :boolean, default: false,
      desc: "Skip turbolinks gem"

    class_option :skip_bundle, type: :boolean, aliases: "-B", default: false,
      desc: "Don't run bundle install"

    def suspenders_customization
      invoke :customize_application_js
      super
    end

    def customize_application_js
      build :application_js
    end

    def outro
      say 'Congratulations! You just pulled our suspenders, Headway style!'
    end

    protected

    def get_builder_class
      Voyage::AppBuilder
    end
  end
end
