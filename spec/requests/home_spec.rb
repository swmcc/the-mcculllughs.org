require 'rails_helper'

RSpec.describe "Home", type: :request do
  describe "GET /" do
    context "when not logged in" do
      it "shows the landing page" do
        get "/"
        expect(response).to have_http_status(:success)
      end
    end

    context "when logged in" do
      let(:user) { create(:user) }

      before { login_as user, scope: :user }

      it "redirects to dashboard" do
        get "/"
        expect(response).to redirect_to(dashboard_path)
      end
    end
  end
end
