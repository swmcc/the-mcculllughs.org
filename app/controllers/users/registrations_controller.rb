class Users::RegistrationsController < Devise::RegistrationsController
  # Disable public sign-ups
  def new
    redirect_to root_path, alert: "Registration is currently closed."
  end

  def create
    redirect_to root_path, alert: "Registration is currently closed."
  end

  def update
    # If password fields are blank, update without password
    if params[:user][:password].blank? && params[:user][:password_confirmation].blank?
      params[:user].delete(:password)
      params[:user].delete(:password_confirmation)
      params[:user].delete(:current_password)

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
    params.require(:user).permit(:name, :email)
  end

  def after_update_path_for(resource)
    edit_user_registration_path
  end
end
