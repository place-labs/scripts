require "http"
require "json"

org = "zone-Hr3IjIN"
building = "zone-Hr3cO8L"
levels = {
  "1." => "zone-HwYTEgQ",
  "2." => "zone-HwY2AO~",
  "3." => "zone-HrluZ~F",
  "4." => "zone-HrK_AhM",
  "5." => "zone-HrL6WGF",
  "6." => "zone-HrLMmD5",
}
api_key = "update me"
domain = "domain.here"

# grab the bookings that are currently valid
params = URI::Params.encode({"booking_type" => "desk", "zones" => org, "limit" => "10000"})
request = URI.new("https", domain, 443, "/api/staff/v1/bookings", params)
response = HTTP::Client.get(request, headers: HTTP::Headers{
  "X-API-Key" => api_key,
  # "Host" => domain,
})
raise "error #{response.status_code}, #{response.body}" unless response.success?
bookings = JSON.parse(response.body).as_a
puts "found #{bookings.size} bookings"

# update the bookings in some way
bad = 0
fixed = 0
bookings.each do |booking|
  asset = booking["asset_id"].as_s
  levels.each do |id, level_zone|
    next unless asset.includes?(id)

    zones = booking["zones"].as_a.map(&.as_s)
    if !zones.includes?(level_zone)
      bad += 1
      zones.concat({building, level_zone}).uniq!
      response = HTTP::Client.put("https://#{domain}/api/staff/v1/bookings/#{booking["id"]}", headers: HTTP::Headers{
        "X-API-Key" => api_key,
        # "Host" => domain,
      }, body: {zones: zones}.to_json)
      fixed += 1 if response.success?
    end
  end
end

puts "found #{bad} bad bookings, fixed #{fixed} bookings"
