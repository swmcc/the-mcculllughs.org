namespace :api_keys do
  desc "Generate a new API key for a user"
  task :generate, [ :email, :name ] => :environment do |_t, args|
    email = args[:email]
    name = args[:name] || "API Key"

    unless email
      puts "Usage: bin/rails api_keys:generate[email,name]"
      puts "Example: bin/rails api_keys:generate[admin@example.com,\"Python Service\"]"
      exit 1
    end

    user = User.find_by(email: email)
    unless user
      puts "Error: User not found with email: #{email}"
      exit 1
    end

    unless user.admin?
      puts "Error: User must be an admin"
      exit 1
    end

    api_key = ApiKey.create!(
      user: user,
      name: name,
      scope: "admin"
    )

    puts "API Key created successfully!"
    puts ""
    puts "Name: #{api_key.name}"
    puts "Key:  #{api_key.key}"
    puts ""
    puts "Store this key securely - it will not be shown again."
    puts ""
    puts "Usage:"
    puts "  curl -H \"Authorization: Bearer #{api_key.key}\" http://localhost:3000/api/v1/admin/stats"
  end

  desc "List all API keys"
  task list: :environment do
    keys = ApiKey.includes(:user).order(created_at: :desc)

    if keys.empty?
      puts "No API keys found."
      exit 0
    end

    puts "ID\tName\t\t\tUser\t\t\tScope\tStatus\t\tLast Used"
    puts "-" * 100

    keys.each do |key|
      status = if key.revoked?
                 "Revoked"
      elsif key.expired?
                 "Expired"
      else
                 "Active"
      end

      last_used = key.last_used_at&.strftime("%Y-%m-%d %H:%M") || "Never"

      puts "#{key.id}\t#{key.name[0..20].ljust(22)}\t#{key.user.email[0..20].ljust(22)}\t#{key.scope}\t#{status.ljust(12)}\t#{last_used}"
    end
  end

  desc "Revoke an API key"
  task :revoke, [ :id ] => :environment do |_t, args|
    id = args[:id]

    unless id
      puts "Usage: bin/rails api_keys:revoke[id]"
      exit 1
    end

    api_key = ApiKey.find_by(id: id)
    unless api_key
      puts "Error: API key not found with ID: #{id}"
      exit 1
    end

    api_key.revoke!
    puts "API key '#{api_key.name}' has been revoked."
  end
end
