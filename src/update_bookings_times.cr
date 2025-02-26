require "http"
require "json"

building = "zone-H9CM"
api_key = "ed34d0fca693355kOEu1GDFPxAueF4qMaF8BU"
domain = "your.domain"

location = Time::Location.load("Australia/Darwin")
starting = Time.local(location)
ending = 12.hours.from_now

# grab the bookings that are currently valid
params = URI::Params.encode({
  "type" => "desk",
  "zones" => building,
  "limit" => "10000",
  "period_start" => starting.to_unix.to_s,
  "period_end" => ending.to_unix.to_s,
})
request = URI.new("https", domain, 443, "/api/staff/v1/bookings", params)
response = HTTP::Client.get(request, headers: HTTP::Headers{
  "X-API-Key" => api_key,
  # "Host" => domain,
})
raise "error #{response.status_code}, #{response.body}" unless response.success?
bookings = JSON.parse(response.body).as_a
puts "returned #{bookings.size} bookings"
bookings.select! { |booking| booking["instance"]?.try(&.as_i64) }
puts "found #{bookings.size} bookings to update"

# update the bookings in some way
bad = 0
fixed = 0
bookings.each do |booking|
  print " -- checking booking #{booking["id"]}"

  response = HTTP::Client.get("https://#{domain}/api/staff/v1/bookings/#{booking["id"]}", headers: HTTP::Headers{
    "X-API-Key" => api_key,
    # "Host" => domain,
  })

  if !response.success?
    puts " > faild to fetch"
    bad += 1
    next
  end

  booking = JSON.parse(response.body)
  starting = Time.unix(booking["booking_start"].as_i64).in(location).at_beginning_of_day + 1.hours
  ending = starting.at_end_of_day - 1.hours

  response = HTTP::Client.put("https://#{domain}/api/staff/v1/bookings/#{booking["id"]}", headers: HTTP::Headers{
    "X-API-Key" => api_key,
    # "Host" => domain,
  }, body: {
    booking_start: starting.to_unix,
    booking_end: ending.to_unix,
    timezone: "Australia/Darwin",
  }.to_json)

  if !response.success?
    puts " > faild to update"
    bad += 1
    next
  end

  puts " > success!"
  fixed += 1
end

puts "fixed #{fixed} bookings, #{bad} failed to update"
