require 'rails_helper'

RSpec.describe ApiKey, type: :model do
  describe "associations" do
    it { should belong_to(:user) }
  end

  describe "validations" do
    it { should validate_presence_of(:name) }

    it "validates uniqueness of key" do
      api_key1 = create(:api_key)
      api_key2 = create(:api_key)
      # Manually set duplicate key after creation callbacks
      api_key2.key = api_key1.key
      expect(api_key2).not_to be_valid
      expect(api_key2.errors[:key]).to include("has already been taken")
    end
  end

  describe "key generation" do
    it "generates a key on create with sk_ prefix" do
      api_key = create(:api_key)
      expect(api_key.key).to start_with("sk_")
      expect(api_key.key.length).to eq(67) # "sk_" + 64 hex chars
    end

    it "generates unique keys" do
      key1 = create(:api_key)
      key2 = create(:api_key)
      expect(key1.key).not_to eq(key2.key)
    end
  end

  describe ".active scope" do
    let(:user) { create(:user) }

    it "returns non-revoked, non-expired keys" do
      active_key = create(:api_key, user: user)
      expect(ApiKey.active).to include(active_key)
    end

    it "excludes revoked keys" do
      revoked_key = create(:api_key, :revoked, user: user)
      expect(ApiKey.active).not_to include(revoked_key)
    end

    it "excludes expired keys" do
      expired_key = create(:api_key, :expired, user: user)
      expect(ApiKey.active).not_to include(expired_key)
    end

    it "includes keys with future expiry" do
      future_key = create(:api_key, user: user, expires_at: 1.year.from_now)
      expect(ApiKey.active).to include(future_key)
    end
  end

  describe "#active?" do
    it "returns true for active key" do
      api_key = create(:api_key)
      expect(api_key.active?).to be true
    end

    it "returns false for revoked key" do
      api_key = create(:api_key, :revoked)
      expect(api_key.active?).to be false
    end

    it "returns false for expired key" do
      api_key = create(:api_key, :expired)
      expect(api_key.active?).to be false
    end
  end

  describe "#touch_last_used!" do
    it "updates last_used_at timestamp" do
      api_key = create(:api_key)
      expect(api_key.last_used_at).to be_nil

      api_key.touch_last_used!
      api_key.reload

      expect(api_key.last_used_at).to be_within(1.second).of(Time.current)
    end
  end
end
