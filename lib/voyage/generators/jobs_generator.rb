require "rails/generators"

module Suspenders
  class JobsGenerator < Rails::Generators::Base
    def configure_background_jobs_for_rspec
      # NOTE: (2017-05-31) jon => don't want this
    end

    def configure_active_job
      # NOTE: (2017-06-02) jon => don't want this
    end
  end
end
