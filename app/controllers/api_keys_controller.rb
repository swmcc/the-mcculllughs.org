# frozen_string_literal: true

class ApiKeysController < ApplicationController
  before_action :set_api_key, only: [ :destroy ]

  def index
    @api_keys = current_user.api_keys.order(created_at: :desc)
  end

  def new
    @api_key = current_user.api_keys.build
  end

  def create
    @api_key = current_user.api_keys.build(api_key_params)

    if @api_key.save
      # Store the key in flash so we can show it once on the next page
      flash[:new_api_key] = @api_key.key
      redirect_to api_key_path(@api_key), notice: "API key created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @api_key = current_user.api_keys.find(params[:id])
    @new_key = flash[:new_api_key]
  end

  def destroy
    @api_key.update!(revoked_at: Time.current)
    redirect_to api_keys_path, notice: "API key '#{@api_key.name}' has been revoked."
  end

  private

  def set_api_key
    @api_key = current_user.api_keys.find(params[:id])
  end

  def api_key_params
    params.require(:api_key).permit(:name)
  end
end
