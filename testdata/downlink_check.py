# Downlink test: sends converter-style "send..." JSON requests to <node root>/2/json/<channel>/test, captures
# what the Xojo app publishes on <node root>/2/e/<channel>/<node id>, and checks it with the official protobufs:
# decryption with the channel key and the firmware's nonce, channel hash, ids, hops and payload.
# The app must be running and connected, with a "node" section in MQTT_Xojo.config.json.
# Note: a gateway with downlink enabled on that channel will really send these into the mesh.
# The direct-message test goes to $DM_TO (e.g. !aabbccdd), else to the first entry of public_keys in the config.
# Usage: python3 testdata/downlink_check.py   (a Python with the meshtastic package; PKI checks also need
# /usr/bin/python3 with the cryptography package, see pki_decrypt.py)
import json, os, subprocess, time, struct, base64, random
from functools import reduce
from meshtastic.protobuf import mqtt_pb2, mesh_pb2, portnums_pb2

here = os.path.dirname(os.path.abspath(__file__))
cfg = json.load(open(os.path.join(here, "..", "MQTT_Xojo.config.json")))
b = cfg["broker"]; node = cfg["node"]
channel = cfg["channels"][0]["name"]
psk = base64.b64decode(cfg["channels"][0]["psk"])
if len(psk) == 1:
    k = bytearray.fromhex("d4f1bb3a20290759f0bcffabcf4e6901"); k[15] = (k[15] + psk[0] - 1) % 256; psk = bytes(k)
key = psk
node_num = int(node["id"][1:], 16)
xor = lambda bs: reduce(lambda a, c: a ^ c, bs, 0)
auth = ["-h", b["host"], "-p", str(b.get("port", 1883))] + (["-u", b["username"], "-P", b["password"]] if b.get("username") else [])
root = node["root"]
send_topic = f"{root}/2/json/{channel}/test"
capture_topic = f"{root}/2/e/{channel}/{node['id']}"
pki_topic = f"{root}/2/e/PKI/{node['id']}"
# DMs to a node whose public key is known go PKI-encrypted (needs node.private_key in the config)
dm_to = os.environ.get("DM_TO") or next(iter(cfg.get("public_keys", {})), "!12345678")
pki_on = bool(node.get("private_key")) and dm_to in cfg.get("public_keys", {})

# Random packet ids for every run: nodes drop a (sender, id) they have seen recently as a duplicate
ids = random.sample(range(0x10000000, 0xFFFFFFFF), 6)
tests = [
    ("text broadcast", {"type": "sendtext", "payload": "Hello from Xojo", "id": ids[0]},
     dict(to=0xFFFFFFFF, port=1, hops=3, text="Hello from Xojo")),
    ("text DM, payload object, hopLimit 2" + (" (PKI)" if pki_on else ""), {"type": "sendtext", "to": dm_to, "payload": {"text": "DM test é"}, "id": ids[1], "hopLimit": 2},
     dict(to=int(dm_to[1:], 16), port=1, hops=2, text="DM test é", pki=pki_on)),
    ("position from decimals", {"type": "sendposition", "payload": {"latitude": 22.3193, "longitude": 114.1694, "altitude": -5, "time": 1790000000}, "id": ids[2]},
     dict(to=0xFFFFFFFF, port=3, hops=3, lat=int(22.3193 * 1e7), lon=int(114.1694 * 1e7), alt=-5, time=1790000000)),
    ("position from _i, explicit from", {"type": "sendposition", "from": 305419896, "payload": {"latitude_i": -337000000, "longitude_i": -700000000}, "id": ids[3]},
     dict(to=0xFFFFFFFF, port=3, hops=3, frm=305419896, lat=-337000000, lon=-700000000)),
]
ignored = [{"type": "sendfoo", "payload": "x", "id": ids[4]}, {"type": "text", "payload": {"text": "uplink JSON"}, "id": ids[5]}]

sub = subprocess.Popen(["mosquitto_sub"] + auth + ["-t", capture_topic, "-t", pki_topic, "-F", "%x", "-W", "8"], stdout=subprocess.PIPE,
                       stderr=subprocess.DEVNULL, text=True)  # -W 8: stop capturing after 8 s (it prints "Timed out")
time.sleep(1)
for _, msg, _ in tests:
    subprocess.run(["mosquitto_pub"] + auth + ["-t", send_topic, "-m", json.dumps(msg)], check=True); time.sleep(0.3)
for msg in ignored:
    subprocess.run(["mosquitto_pub"] + auth + ["-t", send_topic, "-m", json.dumps(msg)], check=True); time.sleep(0.3)
out, _ = sub.communicate()
packets = {}
for line in out.split():
    env = mqtt_pb2.ServiceEnvelope(); env.ParseFromString(bytes.fromhex(line))
    packets[env.packet.id] = env
print(f"captured {len(packets)} packet(s) on {capture_topic} and {pki_topic}")
ok = 0
for name, msg, exp in tests:
    env = packets.get(msg["id"]); problems = []
    if env is None:
        print(f"MISSING  {name}"); continue
    p = env.packet
    frm = exp.get("frm", node_num)
    if getattr(p, "from") != frm: problems.append(f"from {getattr(p, 'from')} != {frm}")
    if p.to != exp["to"]: problems.append(f"to {p.to} != {exp['to']}")
    want_channel = "PKI" if exp.get("pki") else channel
    if env.channel_id != want_channel: problems.append(f"channel_id {env.channel_id!r}")
    if env.gateway_id != node["id"]: problems.append(f"gateway_id {env.gateway_id!r}")
    if p.hop_limit != exp["hops"] or p.hop_start != exp["hops"]: problems.append(f"hops {p.hop_limit}/{p.hop_start}")
    if not p.HasField("encrypted"): problems.append("not encrypted")
    elif exp.get("pki"):
        if not p.pki_encrypted: problems.append("pki_encrypted not set")
        if p.channel != 0: problems.append(f"channel {p.channel} (PKI uses 0)")
        try:
            plain_hex = subprocess.run(["/usr/bin/python3", os.path.join(here, "pki_decrypt.py"), node["private_key"],
                                        cfg["public_keys"][dm_to], str(p.id), str(getattr(p, "from")), p.encrypted.hex()],
                                       capture_output=True, text=True, check=True).stdout.strip()
            d = mesh_pb2.Data(); d.ParseFromString(bytes.fromhex(plain_hex))
            if d.portnum != exp["port"] or d.payload.decode() != exp["text"]: problems.append(f"PKI plaintext {d.portnum} {d.payload!r}")
        except subprocess.CalledProcessError as e:
            problems.append("PKI decryption failed (tag mismatch?): " + e.stderr.strip().splitlines()[-1])
    else:
        h = xor(channel.encode()) ^ xor(key)
        if p.channel != h: problems.append(f"channel hash {p.channel} != {h}")
        nonce = struct.pack("<I", p.id) + bytes(4) + struct.pack("<I", getattr(p, "from")) + bytes(4)
        plain = subprocess.run(["openssl", "enc", "-d", "-aes-%d-ctr" % (len(key) * 8), "-K", key.hex(), "-iv", nonce.hex()],
                               input=p.encrypted, capture_output=True, check=True).stdout
        d = mesh_pb2.Data(); d.ParseFromString(plain)
        if d.portnum != exp["port"]: problems.append(f"portnum {d.portnum}")
        if exp["port"] == 1 and d.payload.decode() != exp["text"]: problems.append(f"text {d.payload!r}")
        if exp["port"] == 3:
            pos = mesh_pb2.Position(); pos.ParseFromString(d.payload)
            for f, v in [("latitude_i", exp["lat"]), ("longitude_i", exp["lon"]), ("altitude", exp.get("alt", 0)), ("time", exp.get("time", 0))]:
                if getattr(pos, f) != v: problems.append(f"{f} {getattr(pos, f)} != {v}")
    print(("OK       " if not problems else "WRONG    ") + name + ("" if not problems else ": " + "; ".join(problems)))
    ok += not problems
for msg in ignored:
    if msg["id"] in packets: print(f"WRONG    published something for {msg['type']!r}")
    else: ok += 1
print(f"{ok}/{len(tests) + len(ignored)} checks passed")
