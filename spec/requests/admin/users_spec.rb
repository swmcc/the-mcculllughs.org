# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Users", type: :request do
  let(:admin) { create(:user, role: :admin) }
  let(:member) { create(:user, role: :member) }

  describe "GET /admin/users" do
    context "when not signed in" do
      it "redirects to sign in" do
        get admin_users_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in as member" do
      before { sign_in member }

      it "redirects with access denied" do
        get admin_users_path
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Access denied.")
      end
    end

    context "when signed in as admin" do
      before { sign_in admin }

      it "returns success" do
        get admin_users_path
        expect(response).to have_http_status(:success)
      end

      it "displays all users" do
        create(:user, name: "Test User")

        get admin_users_path

        expect(response.body).to include("Test User")
        expect(response.body).to include(admin.name)
      end

      it "shows user statistics" do
        create_list(:user, 3)

        get admin_users_path

        expect(response.body).to include("Total Users")
        expect(response.body).to include("Admins")
        expect(response.body).to include("Members")
      end
    end
  end

  describe "DELETE /admin/users/:id" do
    context "when not signed in" do
      it "redirects to sign in" do
        user_to_delete = create(:user)
        delete admin_user_path(user_to_delete)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in as member" do
      before { sign_in member }

      it "redirects with access denied" do
        user_to_delete = create(:user)
        delete admin_user_path(user_to_delete)
        expect(response).to redirect_to(root_path)
      end
    end

    context "when signed in as admin" do
      before { sign_in admin }

      it "deletes another user" do
        user_to_delete = create(:user, name: "Delete Me")

        expect {
          delete admin_user_path(user_to_delete)
        }.to change(User, :count).by(-1)

        expect(response).to redirect_to(admin_users_path)
        expect(flash[:notice]).to include("Delete Me")
      end

      it "prevents deleting yourself" do
        expect {
          delete admin_user_path(admin)
        }.not_to change(User, :count)

        expect(response).to redirect_to(admin_users_path)
        expect(flash[:alert]).to include("can't delete yourself")
      end
    end
  end
end
