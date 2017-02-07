module Api
  module V1
    class UserResource < JSONAPI::Resource
      attributes :email,
                 :roles,
                 :password,
                 :password_confirmation

      def fetchable_fields
        super - [:password, :password_confirmation]
      end
    end
  end
end
