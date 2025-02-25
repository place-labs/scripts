#!/bin/bash

# Define the base URL and common headers
base_url="https://your.domain/api/staff/v1/calendars/availability"
auth_header="Authorization: Bearer eyJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJQT1MiLCRp"
referer_header="Referer: https://your.domain/workplace/"
user_agent_header="User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36 Edg/133.0.0.0"

# Define the period parameters
period_start=1740464700
period_end=1740466500

# List of system IDs
system_ids=(
    "sys-HG34kN8fd-"
    "sys-HG34oTO~rv"
    "sys-HG34gNrvKF"
    "sys-HG34YjacUY"
    "sys-HG34dhqijB"
    "sys-HG34qc2Smv"
    "sys-HG34wHlskO"
    "sys-HG34aeWKUr"
    "sys-HG34lhKZWl"
    "sys-HG34a5GPPs"
    "your system ids here"
)

# Loop through each system_id and measure the request time
for system_id in "${system_ids[@]}"; do
    echo "Measuring time for system_id: $system_id"
    curl -s -o /dev/null -w "@curl-format.txt" \
        -H "$auth_header" \
        -H "$referer_header" \
        -H "$user_agent_header" \
        "$base_url?system_ids=$system_id&period_start=$period_start&period_end=$period_end"
done

