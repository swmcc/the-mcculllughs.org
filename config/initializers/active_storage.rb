# Make Active Storage blobs publicly accessible
# This allows public photo sharing to work without authentication
Rails.application.config.to_prepare do
  ActiveStorage::Blobs::RedirectController.skip_before_action :authenticate_user!, raise: false
  ActiveStorage::Blobs::ProxyController.skip_before_action :authenticate_user!, raise: false
  ActiveStorage::Representations::RedirectController.skip_before_action :authenticate_user!, raise: false
  ActiveStorage::Representations::ProxyController.skip_before_action :authenticate_user!, raise: false
  ActiveStorage::DiskController.skip_before_action :authenticate_user!, raise: false if defined?(ActiveStorage::DiskController)
end
