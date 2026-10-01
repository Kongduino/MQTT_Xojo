# Runs the official converter's own convert_to_json() on every testdata/*.pb and writes testdata/<name>.json.
# Run with a Python that has the meshtastic package: python3 make_golden.py
# paho and cryptography are stubbed out (not needed for conversion); decryption uses the openssl CLI
# with the same nonce as the converter's decrypt_packet().
import sys, types, glob, json, struct, subprocess, os
for name in ["paho", "paho.mqtt", "paho.mqtt.client", "cryptography", "cryptography.hazmat",
             "cryptography.hazmat.primitives", "cryptography.hazmat.primitives.ciphers", "cryptography.hazmat.backends"]:
    sys.modules[name] = types.ModuleType(name)
sys.modules["cryptography.hazmat.primitives.ciphers"].Cipher = None
sys.modules["cryptography.hazmat.primitives.ciphers"].algorithms = None
sys.modules["cryptography.hazmat.primitives.ciphers"].modes = None
sys.modules["cryptography.hazmat.backends"].default_backend = None
# The converter: https://github.com/caveman99/meshtastic-mqtt-converter (clone it next to this repository,
# or set MQTT_CONVERTER to its folder)
sys.path.insert(0, os.environ.get("MQTT_CONVERTER", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "meshtastic-mqtt-converter")))
import meshtastic_protobuf_to_json as conv
from meshtastic.protobuf import mqtt_pb2

from functools import reduce
# Channel keys as configured in the Xojo app (Window1 connect button); the converter takes one --psk,
# so each packet is decrypted with its own channel's key, found by name, then by channel hash
KEYS = {"LongFast": bytes.fromhex("d4f1bb3a20290759f0bcffabcf4e6901"),
        "Team": bytes.fromhex("3a7b1c9e5d2f4a6b8c0d1e2f3a4b5c6d"),
        "Private": bytes.fromhex("9f8e7d6c5b4a39281706f5e4d3c2b1a0112233445566778899aabbccddeeff00")}
xor = lambda b: reduce(lambda a, c: a ^ c, b, 0)
def key_for(env):
    if env.channel_id in KEYS:
        return KEYS[env.channel_id]
    for name, key in KEYS.items():
        if xor(name.encode()) ^ xor(key) == env.packet.channel:
            return key
    return None
converter = object.__new__(conv.MeshtasticConverter)
os.chdir(os.path.dirname(os.path.abspath(__file__)))
for pb in sorted(glob.glob("*.pb")):
    env = mqtt_pb2.ServiceEnvelope()
    env.ParseFromString(open(pb, "rb").read())
    p = env.packet
    key = key_for(env)
    if p.HasField("encrypted") and key is not None:
        nonce = struct.pack("<I", p.id) + bytes(4) + struct.pack("<I", getattr(p, "from")) + bytes(4)
        plain = subprocess.run(["openssl", "enc", "-d", "-aes-%d-ctr" % (len(key) * 8), "-K", key.hex(), "-iv", nonce.hex()],
                               input=p.encrypted, capture_output=True, check=True).stdout
        p.decoded.ParseFromString(plain)
    data = converter.convert_to_json(env)
    out = json.dumps(data, separators=(',', ':'), sort_keys=True) if data else ""
    open(pb[:-3] + ".json", "w").write(out + "\n")
    print(f"{pb:28} {out if out else '(nothing published)'}")
