#!/usr/bin/env bash

#Check if XMLStarlet is installed
if ! command -v xmlstarlet >/dev/null 2>&1; then
  echo "Script exited. Please install xmlstarlet to continue."
  exit 1
fi

#Source the .env file
source $(dirname "$0")/.env

#Send message to ntfy
ntfy_message() {
  cat <<EOF
{
  "topic": "$ntfy_topic",
  "tags": ["x"],
  "title": "Recall",
  "message": "$title"
}
EOF
}

#Forge notification to ntfy
send_ntfy() {
  if [ "$ntfy_password" ]; then
      curl -H "Content-Type: application/json" \
          -H "Actions: view, View more, $link" \
          -u "$ntfy_user:$ntfy_password" \
          -d "$(ntfy_message)" \
          $ntfy_url

  elif [ "$ntfy_accesstoken" ]; then
      curl -H "Content-Type: application/json" \
          -H "Actions: view, View more, $link" \
          -H "Authorization: Bearer $ntfy_accesstoken" \
          -d "$(ntfy_message)" \
          $ntfy_url
  fi
}

#Process item from XML and send a notification if it is new
process_item() {
  local title="$1"
  local link="$2"
  local pubDate="$3"

  touch $(dirname "$0")/old_recalls.txt
  if ! grep "$title $pubDate" $(dirname "$0")/old_recalls.txt ; then
      send_ntfy
      echo "$title $pubDate" >> $(dirname "$0")/old_recalls.txt
  fi
}


#Fetch the RSS feeds and process them
wget -qO- "https://www.konsumentverket.se/aktuellt/aterkallelser-av-varor/?format=rss" > /tmp/kv_rss.xml
wget -qO- "https://www.livsmedelsverket.se/rss/rss-aterkallanden" > /tmp/lv_rss.xml

xmlstarlet sel -t -m "//item" -v "concat(title, '|', link, '|', pubDate)" -n "/tmp/kv_rss.xml" | while IFS="|||" read -r title link pubDate

do
  process_item "$title" "$link" "$pubDate"
done

xmlstarlet sel -t -m "//item" -v "concat(title, '|', link, '|', pubDate)" -n "/tmp/lv_rss.xml" | while IFS="|||" read -r title link pubDate

do
  process_item "$title" "$link" "$pubDate"
done

#Clean up temporary files
rm /tmp/kv_rss.xml
rm /tmp/lv_rss.xml

