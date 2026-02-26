require 'rails_helper'

RSpec.describe User, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:galleries).dependent(:destroy) }
    it { is_expected.to have_many(:uploads).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:role) }
  end

  describe "roles" do
    it { is_expected.to define_enum_for(:role).with_values(member: 0, admin: 1) }

    it "defaults to member" do
      user = create(:user)
      expect(user.role).to eq("member")
    end

    it "can be set to admin" do
      user = create(:user, :admin)
      expect(user).to be_admin
    end
  end

  describe "devise" do
    it "is database authenticatable" do
      user = create(:user, password: "password12345")
      expect(user.valid_password?("password12345")).to be true
    end
  end
end
