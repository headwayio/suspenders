module Suspenders
  class CiGenerator < Rails::Generators::Base
    def configure_ci
      template "../templates/circle_config.yml.erb", ".circleci/config.yml"
      template "../templates/codeclimate.yml", ".codeclimate.yml"
    end
  end
end
