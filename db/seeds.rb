User.find_or_create_by!(email_address: "admin@paynow.mx") do |u|
  u.password = "admin1234"
  u.password_confirmation = "admin1234"
  u.role = :super_admin
end

puts "Super admin: admin@paynow.mx / admin1234"
