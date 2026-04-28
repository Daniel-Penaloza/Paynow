# ── Super Admin ───────────────────────────────────────────
admin = User.find_or_create_by!(email_address: "admin@paynow.mx") do |u|
  u.password = "admin1234"
  u.password_confirmation = "admin1234"
  u.role = :super_admin
end
puts "Super Admin:     admin@paynow.mx / admin1234"

# ── Organización de prueba ────────────────────────────────
org = Organization.find_or_create_by!(subdomain: "garcia") do |o|
  o.name = "Familia García"
end
puts "Organización:    #{org.name} (#{org.subdomain}.paynow.mx)"

# ── Business Owner ────────────────────────────────────────
owner = User.find_or_create_by!(email_address: "garcia@paynow.mx") do |u|
  u.password = "owner1234"
  u.password_confirmation = "owner1234"
  u.role = :business_owner
  u.organization = org
end
puts "Business Owner:  garcia@paynow.mx / owner1234"

# ── Negocios ──────────────────────────────────────────────
abarrotes = Business.find_or_create_by!(slug: "abarrotes-garcia") do |b|
  b.name         = "Abarrotes García"
  b.clabe        = "646180157000000001"
  b.holder_name  = "María García López"
  b.whatsapp     = "5512345678"
  b.instructions = "Indica tu nombre en el concepto de la transferencia."
  b.user         = owner
end
puts "Negocio:         #{abarrotes.name} → garcia.lvh.me:3000/#{abarrotes.slug}"

taqueria = Business.find_or_create_by!(slug: "taqueria-el-patron") do |b|
  b.name         = "Taquería El Patrón"
  b.clabe        = "646180157000000002"
  b.holder_name  = "José García Ruiz"
  b.user         = owner
end
puts "Negocio:         #{taqueria.name} → garcia.lvh.me:3000/#{taqueria.slug}"
