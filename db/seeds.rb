# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Seeding database..."

# Create admin user
admin = User.find_or_create_by!(email: "admin@the-mcculloughs.org") do |user|
  user.name = "Admin User"
  user.password = "password1234"
  user.password_confirmation = "password1234"
  user.role = :admin
end
puts "✅ Created admin user: #{admin.email}"

# Create member users
member1 = User.find_or_create_by!(email: "john@the-mcculloughs.org") do |user|
  user.name = "John McCullough"
  user.password = "password1234"
  user.password_confirmation = "password1234"
  user.role = :member
end
puts "✅ Created member user: #{member1.email}"

member2 = User.find_or_create_by!(email: "jane@the-mcculloughs.org") do |user|
  user.name = "Jane McCullough"
  user.password = "password1234"
  user.password_confirmation = "password1234"
  user.role = :member
end
puts "✅ Created member user: #{member2.email}"

# Create sample galleries
gallery1 = Gallery.find_or_create_by!(title: "Family Vacation 2024") do |gallery|
  gallery.description = "Our amazing summer trip to the coast"
  gallery.user = member1
end
puts "✅ Created gallery: #{gallery1.title}"

gallery2 = Gallery.find_or_create_by!(title: "Holiday Celebrations") do |gallery|
  gallery.description = "Christmas and New Year festivities with the family"
  gallery.user = member2
end
puts "✅ Created gallery: #{gallery2.title}"

gallery3 = Gallery.find_or_create_by!(title: "Kids' Birthday Parties") do |gallery|
  gallery.description = "Birthday celebrations and fun moments"
  gallery.user = admin
end
puts "✅ Created gallery: #{gallery3.title}"

puts "🎉 Seeding complete!"
puts ""
puts "📧 You can log in with:"
puts "   Admin: admin@the-mcculloughs.org / password1234"
puts "   Member 1: john@the-mcculloughs.org / password1234"
puts "   Member 2: jane@the-mcculloughs.org / password1234"
