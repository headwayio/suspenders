module Api
  module V1
    class UsersController < BaseApiController
      # Warning:
      # By default the ability to create an account via API is left wide open
      load_and_authorize_resource except: [:create]
      skip_authorization_check only: [:create]
      skip_before_action :authenticate_user!, only: [:create]

      def index
        jsonapi_render json: User.all
      end

      def show
        jsonapi_render json: @user
      end

      def create
        @user = User.new(user_params)
        # @user.roles << :user

        if @user.save
          # On successful creation, generate token and return in response
          token = Tiddle.create_and_return_token(@user, request)
          json = JSONAPI::ResourceSerializer
                 .new(Api::V1::UserResource)
                 .serialize_to_hash(Api::V1::UserResource.new(@user, nil))

          render json: json.merge(
            meta: {
              authentication_token: token,
            },
          )
        else
          jsonapi_render_errors json: @user, status: :unprocessable_entity
        end
      end

      def update
        if @user.update_attributes(user_params)
          jsonapi_render json: @user
        else
          jsonapi_render_errors json: @user, status: :unprocessable_entity
        end
      end

      def destroy
        @user.destroy
        head :no_content
      end

      private

      def user_params
        resource_params
      end
    end
  end
end
