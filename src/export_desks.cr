require "option_parser"
require "placeos"
require "uuid"
require "set"
require "csv"

# defaults if you don't want to use command line options
api_key = "MB3c"
place_domain = "https://placeos.au"
csv_file = "desk_export.csv"
building_zone = "zone-1234"

# Command line options
OptionParser.parse do |parser|
  parser.banner = "Usage: #{PROGRAM_NAME} [arguments]"

  parser.on("-d DOMAIN", "--domain=DOMAIN", "the domain of the PlaceOS server") do |dom|
    place_domain = dom
  end

  parser.on("-b BUILDING", "--building=BUILDING", "the building zone") do |building|
    building_zone = building
  end

  parser.on("-k API_KEY", "--api_key=API_KEY", "placeos API key for access") do |key|
    api_key = key
  end

  parser.on("-i CSV", "--export=CSV", "csv file to export") do |file|
    csv_file = file
  end

  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit 0
  end
end

# ======================================
# Grab existing building information
# ======================================

# Configure the PlaceOS client
client = PlaceOS::Client.new(place_domain,
  x_api_key: api_key,
  insecure: true, # if using a self signed certificate
)

puts "================================="
puts "obtaining building information..."

building = client.zones.fetch(building_zone)

puts "================================="
puts "writing desk metadata..."

desk_count = 0
level_count = 0

# Array(NamedTuple(zone: API::Models::Zone, metadata: Hash(String, API::Models::Metadata)))
levels = client.metadata.children(building_zone, "desks")
File.open(csv_file, "w") do |file|
  CSV.build(file) do |csv|
    csv.row "building name", "building display name", "level name", "level display name", "desk id", "desk map id", "desk name", "security group", "assigned email", "assigned name"

    building_name = building.name
    build_display_name = building.display_name || ""

    levels.each do |level|
      zone = level[:zone]
      metadata = level[:metadata]["desks"]?
      next unless metadata
      desks = metadata.details.as_a?
      next unless desks

      level_name = zone.name
      level_display_name = zone.display_name || ""
      level_count += 1

      desks.each do |desk|
        desk_id = desk["id"].as_s
        map_id = desk["map_id"]?.try(&.as_s?) || desk_id
        desk_name = desk["name"]?.try(&.as_s?) || desk_id
        security_group = desk["security"]?.try(&.as_s?) || ""
        assigned_email = desk["assigned_to"]?.try(&.as_s?) || ""
        assigned_name = desk["assigned_name"]?.try(&.as_s?) || ""

        desk_count += 1

        csv.row building_name, build_display_name, level_name, level_display_name, desk_id, map_id, desk_name, security_group, assigned_email, assigned_name
      end
    end
  end
end

puts "================================="
puts "COMPLETE"
puts "================================="

puts "output #{level_count} levels"
puts "       #{desk_count} desks"
