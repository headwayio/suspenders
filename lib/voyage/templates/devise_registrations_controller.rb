module DeviseCustomizations
  class RegistrationsController < Devise::RegistrationsController
    def create
      super
    end

    protected

    def after_sign_up_path_for(resource)
      if user_signed_in?
        analytics_alias_user_path(resource)
      else
        new_user_session_path(resource)
      end
    end
  end
end
