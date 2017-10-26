module Api
  class BaseApiController < ApplicationController
    include JSONAPI::Utils

    # Disable CSRF protection for API calls
    protect_from_forgery with: :null_session, prepend: true

    # Disable cookie usage
    before_action :destroy_session

    # Handle objects that aren't found
    rescue_from ActiveRecord::RecordNotFound, with: :jsonapi_render_not_found

    def respond_with_errors(object)
      serialized_errors = object.errors.messages.map do |field, errors|
        errors.map do |error_message|
          {
            status: 422,
            source: { pointer: "/data/attributes/#{field}" },
            detail: error_message,
          }
        end
      end.flatten

      render json: { errors: serialized_errors },
             status: :unprocessable_entity
    end

    private

    def destroy_session
      request.session_options[:skip] = true
    end
  end
end
