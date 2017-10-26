class ImagesController < ApplicationController
  load_and_authorize_resource
  respond_to :json

  def create
    if image_params[:image].tempfile.closed?
      image_params[:image].open()
    end

    @image = Image.new(image_params)

    respond_to do |format|
      if @image.save
        # format.html { redirect_to @image, notice: 'Image was successfully created.' }
        format.json { render json: { url: @image.image_url }, status: :ok }
      else
        # format.html { render :new }
        format.json { render json: @image.errors, status: :unprocessable_entity }
      end
    end
  end

  private

  def image_params
    params.require(:image).permit(:image)
  end
end
