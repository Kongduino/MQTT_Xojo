# Rebuilds the MQTT byte stream from the hexDump blocks of a saved app output, extracts every PUBLISH
# on a /2/e/ topic, runs the official converter's convert_to_json() on it, and compares with the
# app's "  JSON -> " lines. Usage: python3 live_check.py ../result8.txt
import sys, re, json, os
sys.argv_file = sys.argv[1]
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "make_golden.py")).read().split("converter = object.__new__")[0])
converter = object.__new__(conv.MeshtasticConverter)
# channel keys from ../MQTT_Xojo.config.json, expanded like the firmware (1-byte PSK = default key variant)
import base64
cfg = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "MQTT_Xojo.config.json")))
KEYS = {}
for c in cfg["channels"]:
    b = base64.b64decode(c["psk"])
    if len(b) == 1:
        k = bytearray.fromhex("d4f1bb3a20290759f0bcffabcf4e6901"); k[15] = (k[15] + b[0] - 1) % 256; b = bytes(k)
    KEYS[c["name"]] = b
text = open(sys.argv_file, encoding="utf-8").read()
stream = bytearray()
for line in text.splitlines():
    m = re.match(r'^[0-9a-fA-F]{3}\.\|((?:[0-9A-F]{2} )+)', line)
    if m:
        stream += bytes.fromhex(m.group(1).replace(" ", ""))
app_json = {}
for line in text.splitlines():
    if line.startswith("  JSON -> "):
        j = line.split(": ", 1)[1]
        app_json[json.loads(j)["id"]] = j
pos = 0; checked = same = 0
while pos < len(stream):
    first = stream[pos]; mult = 1; length = 0; i = pos + 1
    while True:
        b = stream[i]; length += (b & 0x7F) * mult; mult *= 128; i += 1
        if not b & 0x80: break
    body = bytes(stream[i:i + length]); pos = i + length
    if first >> 4 != 3: continue
    tl = int.from_bytes(body[:2], "big"); topic = body[2:2 + tl].decode(); rest = body[2 + tl:]
    if (first >> 1) & 3: rest = rest[2:]
    if "/2/e/" not in topic: continue
    env = mqtt_pb2.ServiceEnvelope(); env.ParseFromString(rest)
    p = env.packet
    key = key_for(env)
    was_encrypted = p.HasField("encrypted")
    if p.HasField("encrypted") and key is not None:
        nonce = struct.pack("<I", p.id) + bytes(4) + struct.pack("<I", getattr(p, "from")) + bytes(4)
        plain = subprocess.run(["openssl", "enc", "-d", "-aes-%d-ctr" % (len(key) * 8), "-K", key.hex(), "-iv", nonce.hex()],
                               input=p.encrypted, capture_output=True, check=True).stdout
        p.decoded.ParseFromString(plain)
    print(f"{topic}: id {p.id}, {('decrypted port ' + str(p.decoded.portnum) if key is not None else 'encrypted, no key') if was_encrypted else 'plain port ' + str(p.decoded.portnum)}, channel {p.channel}")
    data = converter.convert_to_json(env)
    exp = json.dumps(data, separators=(',', ':'), sort_keys=True) if data else ""
    got = app_json.get(p.id, "")
    checked += 1; same += (exp == got)
    print("   " + ("same" if exp == got else f"DIFFERENT\n   converter: {exp}\n   xojo:      {got}"))
print(f"{same}/{checked} packets: Xojo JSON identical to the converter's")
