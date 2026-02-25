class Users::RegistrationsController < Devise::RegistrationsController
  def update
    # If password fields are blank, update without password
    if params[:user][:password].blank? && params[:user][:password_confirmation].blank?
      params[:user].delete(:password)
      params[:user].delete(:password_confirmation)
      params[:user].delete(:current_password)

      # Don't update spotify_client_secret if blank (preserve existing)
      if params[:user][:spotify_client_secret].blank?
        params[:user].delete(:spotify_client_secret)
      end

      if resource.update(account_update_params_without_password)
        bypass_sign_in resource, scope: resource_name
        redirect_to edit_user_registration_path, notice: "Settings updated successfully."
      else
        render :edit, status: :unprocessable_content
      end
    else
      # Changing password requires current password
      super
    end
  end

  protected

  def account_update_params_without_password
    params.require(:user).permit(:name, :email, :spotify_client_id, :spotify_client_secret)
  end

  def after_update_path_for(resource)
    edit_user_registration_path
  end
end
