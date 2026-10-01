#!/bin/zsh
# Publishes every Meshtastic test packet (testdata/*.pb) to the broker in ../MQTT_Xojo.config.json.
# Usage: testdata/publish_tests.sh
cd "$(dirname "$0")"
CONFIG=../MQTT_Xojo.config.json
cfg() { python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["broker"].get(sys.argv[2], sys.argv[3]))' "$CONFIG" "$1" "$2"; }
HOST=$(cfg host "")
PORT=$(cfg port 1883)
USER_NAME=$(cfg username "")
PASSWORD=$(cfg password "")
# Topic root: $TOPIC_ROOT, else node.root from the config, else msh/test. Subscribe the app to <root>/#
ROOT=${TOPIC_ROOT:-$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1])).get("node", {}).get("root", "msh/test"))' "$CONFIG")}
for f in *.pb; do
  mosquitto_pub -h "$HOST" -p "$PORT" -u "$USER_NAME" -P "$PASSWORD" \
    -t "$ROOT/2/e/LongFast/!deadbeef" -f "$f"
  sleep 0.3
done
