# frozen_string_literal: true

module Admin
  class UsersController < BaseController
    def index
      @users = User.includes(:galleries, :uploads, :slideshows)
                   .order(created_at: :desc)

      @stats = {
        total: @users.count,
        admins: @users.admin.count,
        members: @users.member.count,
        total_uploads: Upload.count,
        total_galleries: Gallery.count,
        public_uploads: Upload.where(is_public: true).count
      }
    end

    def destroy
      @user = User.find(params[:id])

      if @user == current_user
        redirect_to admin_users_path, alert: "You can't delete yourself."
        return
      end

      @user.destroy
      redirect_to admin_users_path, notice: "#{@user.name} has been deleted."
    end
  end
end
