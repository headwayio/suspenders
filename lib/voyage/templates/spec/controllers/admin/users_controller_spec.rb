require 'rails_helper'

RSpec.describe Admin::UsersController, type: :request do
  it_behaves_like 'dashboard' do
    let(:path) { admin_users_path }
  end

  context 'impersonation' do
    let(:user) { create(:user) }
    let(:admin_user) { create(:user, :admin) }

    describe '#impersonate' do
      it 'changes the current user from admin to the specified user' do
        sign_in(admin_user)
        get impersonate_admin_user_path(user)
        expect(controller.current_user).to eq(user)
      end
    end

    describe '#stop_impersonating' do
      it 'returns the current_user to the admin user' do
        sign_in(admin_user)
        get impersonate_admin_user_path(user)
        expect(controller.current_user).to eq(user)
        get stop_impersonating_admin_users_path
        expect(controller.current_user).to eq(admin_user)
      end
    end
  end
end
