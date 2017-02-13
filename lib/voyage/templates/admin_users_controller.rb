module Admin
  class UsersController < ApplicationController
    before_action :require_admin!, except: [:stop_impersonating]
    skip_authorization_check

    def index
      @users = User.all
    end

    def impersonate
      user = User.find(params[:id])
      track_impersonation(user, 'Start')
      impersonate_user(user)
      redirect_to root_path
    end

    def stop_impersonating
      track_impersonation(current_user, 'Stop')
      stop_impersonating_user
      redirect_to admin_users_path
    end

    private

    def require_admin!
      txt = 'You must be an admin to perform that action'
      redirect_to root_path, notice: txt unless current_user.admin?
    end

    def track_impersonation(user, status)
      analytics_track(
        true_user,
        "Impersonation #{status}",
        impersonated_user_id: user.id,
        impersonated_user_email: user.email,
        impersonated_by_email: true_user.email,
      )
    end
  end
end
