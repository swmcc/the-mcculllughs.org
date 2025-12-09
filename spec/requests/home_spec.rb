require 'rails_helper'

RSpec.describe "Home", type: :request do
  let(:user) { create(:user) }

  before { login_as user, scope: :user }

  describe "GET /" do
    it "returns http success" do
      get "/"
      expect(response).to have_http_status(:success)
    end
  end
end
