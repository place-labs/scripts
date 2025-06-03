require "http"
require "json"

org = "zone-EFejbYY"
campus = "zone-GSD8J6Y"
building = "zone-H9CMyjX"
api_key = "ed34d0fc.eF4qMaF8BU"
domain = "domain.au"

# ==========================
# find all the desk mappings
# ==========================
# desk id => assignment email
desk_ids = Set(String).new

response = HTTP::Client.get("https://#{domain}/api/engine/v2/metadata/#{building}/children?include_parent=false&name=desks", headers: HTTP::Headers{
  "X-API-Key" => api_key,
  "Host"      => domain,
})
raise "unable to fetch building zones" unless response.success?

record DeskDetails, desk_id : String, assigned_email : String, assigned_name : String, level_zone : String, desk_name : String

# email => [] of desks
assigned_to = Hash(String, Array(DeskDetails)).new do |hash, key|
  hash[key] = [] of DeskDetails
end

# desk_id => DeskDetails
assignments = {} of String => DeskDetails

json = JSON.parse(response.body)
json.as_a.each do |level|
  level_zone = level["zone"]["id"].as_s

  if desks = level["metadata"]["desks"]?
    desks["details"].as_a.each do |desk|
      assigned_email = desk["assigned_to"]?.try(&.as_s?).presence
      next unless assigned_email
      assigned_email = assigned_email.strip.downcase
      assigned_name = desk["assigned_name"]?.try(&.as_s?)

      if assigned_name.nil?
        puts "no assigned name for desk #{assigned_email}"
        assigned_name = assigned_email.split('@')[0].gsub('.', ' ')
      end

      desk_id = desk["id"].as_s
      desk_name = desk["name"]?.try(&.as_s?) || desk_id
      details = DeskDetails.new(desk_id, assigned_email, assigned_name, level_zone, desk_name)

      assignments[desk_id] = details
      assigned_to[assigned_email] << details
    end
  end
end

location = Time::Location.load("Australia/Darwin")
starting = Time.local(location)
ending = 2.hours.from_now

booking_start = starting.at_beginning_of_day
booking_end = starting.at_end_of_day

# ===================================
# find all the booking allocation ids
# ===================================

# find all the recurring bookings for the building
params = URI::Params.encode({
  "type"         => "desk",
  "zones"        => building,
  "limit"        => "10000",
  "period_start" => starting.to_unix.to_s,
  "period_end"   => ending.to_unix.to_s,
})
request = URI.new("https", domain, 443, "/api/staff/v1/bookings", params)
response = HTTP::Client.get(request, headers: HTTP::Headers{
  "X-API-Key" => api_key,
  # "Host" => domain,
})
raise "error #{response.status_code}, #{response.body}" unless response.success?
bookings = JSON.parse(response.body).as_a
bookings.select! { |booking| booking["recurrence_type"].as_s? == "daily" && booking["recurrence_end"]?.try(&.as_i64?).nil? }

# find all the missing assignments or incorrect assignments
missing = {} of String => DeskDetails
deleted = {} of Int64 => String
failed = 0
assignments.each do |desk_id, details|
  booking = bookings.find { |book| book["asset_id"].as_s == desk_id }
  if booking.nil?
    missing[desk_id] = details
    next
  end

  booking_email = booking["user_email"].as_s.strip.downcase
  if booking_email != details.assigned_email
    booking_id = booking["id"].as_i64

    # this is an incorrect booking, we should delete it
    # then we can add the current assignment to missing
    request = URI.new("https", domain, 443, "/api/staff/v1/bookings/#{booking_id}")
    response = HTTP::Client.delete(request, headers: HTTP::Headers{
      "X-API-Key" => api_key,
      # "Host" => domain,
    })

    if !response.success?
      puts "  - failed to delete: #{booking_id} owned by #{booking_email}"
      puts "error: #{response.status_code}\n#{response.body}"
      raise "fatal, exiting due to cleanup error"
    end

    deleted[booking_id] = booking_email
    missing[desk_id] = details
  end
end

puts "checked #{assignments.size} assignments against #{bookings.size} bookings"
puts "failed to remove #{failed} bookings" unless failed.zero?
puts "removed #{deleted.size} incorrect assignments"
deleted.each do |booking_id, email|
  puts "  - #{email}: #{booking_id}"
end
puts "found #{missing.size} missing assignments"
puts "creating missing bookings..." unless missing.size.zero?

# update the bookings with the new ids
fixed = 0
no_applied = {} of String => String
missing.each do |desk_id, details|
  puts "  - assigning #{desk_id} => #{details.assigned_email}"

  payload = {
    "asset_id"  => desk_id,
    "asset_ids" => [
      desk_id,
    ],
    "asset_name" => details.desk_name,
    "zones"      => [
      org,
      campus,
      building,
      details.level_zone,
    ],
    "booking_start"  => booking_start.to_unix,
    "booking_end"    => booking_end.to_unix,
    "booking_type"   => "desk",
    "type"           => "desk",
    "timezone"       => "Australia/Darwin",
    "user_email"     => details.assigned_email,
    "user_id"        => details.assigned_email,
    "user_name"      => details.assigned_name,
    "title"          => "Desk Booking",
    "checked_in"     => false,
    "rejected"       => false,
    "approved"       => false,
    "deleted"        => false,
    "extension_data" => {
      "asset_name"  => details.desk_name,
      "is_assigned" => true,
      "assets"      => [] of String,
      "tags"        => [] of String,
    },
    "access"          => false,
    "permission"      => "PRIVATE",
    "attendees"       => [] of String,
    "tags"            => [] of String,
    "images"          => [] of String,
    "all_day"         => false,
    "linked_bookings" => [] of String,
    "status"          => "tentative",
    "recurrence_type" => "daily",
    "recurrence_days" => 127,
  }.to_json

  request = URI.new("https", domain, 443, "/api/staff/v1/bookings")
  response = HTTP::Client.post(request, headers: HTTP::Headers{
    "X-API-Key" => api_key,
    # "Host" => domain,
  }, body: payload)

  if response.success?
    fixed += 1
  else
    no_applied[desk_id] = details.assigned_email
    puts "    failed to assign with #{response.status_code}\n#{response.body}"
    raise "fatal, exiting due to failure"
  end
end

puts "added #{fixed} missing bookings" unless missing.size.zero?
if !no_applied.size.zero?
  puts "failed to apply #{no_applied.size} bookings"
end
puts "done!"
