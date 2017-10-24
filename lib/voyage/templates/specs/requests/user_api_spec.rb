require 'rails_helper'

describe '/api/v1/users Endpoints', type: :request do
  let(:user) { create(:user) }

  before { authenticate(user) }

  describe 'GET /users' do
    before do
      10.times { create(:user) }
    end

    it 'returns list of users' do
      authed_get api_v1_users_url
      json_body = JSON.parse(response.body)

      expect(json_body.count).to eq 11
    end
  end

  describe 'GET /users/:id' do
    it 'returns an individual user' do
      authed_get api_v1_user_url(user.id)
      json_body = JSON.parse(response.body)

      expect(json_body['email']).to eq user.email
    end
  end

  describe 'POST /users' do
    attributes = {
      email: 'testemail@example.com',
    }

    context 'successful' do
      it 'creates a user' do
        params = {
          user: {
            password: 'password',
            password_confirmation: 'password',
          }.merge(attributes),
        }

        authed_post api_v1_users_path, params
        json_body = JSON.parse(response.body)

        expect(json_body['email']).to eq attributes[:email]
      end
    end

    context 'unsuccessful' do
      it 'does not create a user' do
        params = {
          user: {
            password: 'password',
            password_confirmation: 'password',
          },
        }

        authed_post api_v1_users_path, params
        json_body = JSON.parse(response.body)

        email_errors = json_body['errors'].select do |e|
          e['source']['pointer'] == '/data/attributes/email' &&
            e['detail'] == 'is invalid'
        end

        expect(email_errors.count).to eq 1
      end
    end
  end

  describe 'PATCH /users/:id' do
    context 'successful' do
      it 'updates the user' do
        params = {
          user: {
            email: 'newemail@example.com',
          },
        }

        authed_patch api_v1_user_path(user.id), params

        expect(response.status).to eq 204
      end
    end

    context 'unsuccessful' do
      it 'does not update the user' do
        params = {
          user: {
            email: '',
          },
        }

        authed_patch api_v1_user_path(user.id), params
        json_body = JSON.parse(response.body)

        expect(response.status).to eq 422

        email_errors = json_body['errors'].select do |e|
          e['source']['pointer'] == '/data/attributes/email' &&
            e['detail'] == "can't be blank"
        end

        expect(email_errors.count).to be > 1
      end
    end
  end

  describe 'DELETE /users/:id' do
    it 'deletes the user' do
      authed_delete api_v1_user_path(user.id)
      expect(response.status).to eq 200
    end
  end
end
