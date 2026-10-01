# Builds Meshtastic ServiceEnvelope test packets (binary .pb files) with the official protobufs.
# Run with a Python that has the meshtastic package (pip install meshtastic): python3 make_testdata.py
import struct
from meshtastic.protobuf import mqtt_pb2, mesh_pb2, portnums_pb2, telemetry_pb2

DEFAULT_KEY = bytes([0xd4, 0xf1, 0xbb, 0x3a, 0x20, 0x29, 0x07, 0x59,
                     0xf0, 0xbc, 0xff, 0xab, 0xcf, 0x4e, 0x69, 0x01])

def envelope(from_node, to_node, packet_id):
    e = mqtt_pb2.ServiceEnvelope(channel_id="LongFast", gateway_id="!deadbeef")
    p = e.packet
    setattr(p, "from", from_node)
    p.to = to_node
    p.id = packet_id
    p.rx_time = 1790000000
    p.rx_rssi = -95
    p.rx_snr = -7.25
    p.hop_limit = 2
    p.hop_start = 3
    return e

def save(name, e):
    data = e.SerializeToString()
    open(name, "wb").write(data)
    print(f"{name:24} {len(data):4} bytes")

# 1. Plain text broadcast (unencrypted)
e = envelope(0xa1b2c3d4, 0xffffffff, 0x11111111)
e.packet.decoded.portnum = portnums_pb2.TEXT_MESSAGE_APP
e.packet.decoded.payload = "Hello from Xojo test".encode()
save("text.pb", e)

# 2. Position, direct message to another node (unencrypted)
e = envelope(0x0badcafe, 0x12345678, 0x22222222)
pos = mesh_pb2.Position(latitude_i=223193000, longitude_i=1141694000, altitude=42, time=1790000000)
e.packet.decoded.portnum = portnums_pb2.POSITION_APP
e.packet.decoded.payload = pos.SerializeToString()
save("position.pb", e)

# 3. Device telemetry (unencrypted)
e = envelope(0xa1b2c3d4, 0xffffffff, 0x33333333)
t = telemetry_pb2.Telemetry(time=1790000000)
t.device_metrics.battery_level = 87
t.device_metrics.voltage = 4.05
t.device_metrics.channel_utilization = 12.5
t.device_metrics.air_util_tx = 1.25
t.device_metrics.uptime_seconds = 3600
e.packet.decoded.portnum = portnums_pb2.TELEMETRY_APP
e.packet.decoded.payload = t.SerializeToString()
save("telemetry.pb", e)

def encrypt(e, data):
    # AES-128-CTR with the default key via the openssl CLI (no extra Python package needed)
    import subprocess
    nonce = struct.pack("<I", e.packet.id) + bytes(4) + struct.pack("<I", getattr(e.packet, "from")) + bytes(4)
    e.packet.encrypted = subprocess.run(
        ["openssl", "enc", "-aes-128-ctr", "-K", DEFAULT_KEY.hex(), "-iv", nonce.hex()],
        input=data.SerializeToString(), capture_output=True, check=True).stdout

# 4. Text, encrypted with the default LongFast key (AQ==), as on the public broker.
#    AES-128-CTR via the openssl CLI (no extra Python package needed).
import subprocess
e = envelope(0xa1b2c3d4, 0xffffffff, 0x44444444)
data = mesh_pb2.Data(portnum=portnums_pb2.TEXT_MESSAGE_APP, payload="Secret hello".encode())
nonce = struct.pack("<I", e.packet.id) + bytes(4) + struct.pack("<I", 0xa1b2c3d4) + bytes(4)
e.packet.encrypted = subprocess.run(
    ["openssl", "enc", "-aes-128-ctr", "-K", DEFAULT_KEY.hex(), "-iv", nonce.hex()],
    input=data.SerializeToString(), capture_output=True, check=True).stdout
save("text_encrypted.pb", e)

# 5. NodeInfo (unencrypted)
e = envelope(0xa1b2c3d4, 0xffffffff, 0x55555555)
user = mesh_pb2.User(id="!a1b2c3d4", long_name="Test T-Echo", short_name="DDA",
                     hw_model=mesh_pb2.HardwareModel.T_ECHO, role=0)
e.packet.decoded.portnum = portnums_pb2.NODEINFO_APP
e.packet.decoded.payload = user.SerializeToString()
save("nodeinfo.pb", e)

# 6. Position below sea level (negative altitude = 10-byte varint), encrypted
e = envelope(0x0badcafe, 0xffffffff, 0x66666666)
pos = mesh_pb2.Position(latitude_i=-337000000, longitude_i=-700000000, altitude=-28,
                        time=1790000000, sats_in_view=9, precision_bits=32)
encrypt(e, mesh_pb2.Data(portnum=portnums_pb2.POSITION_APP, payload=pos.SerializeToString()))
save("position_encrypted.pb", e)

# 7. Multi-line text (shown on one line)
e = envelope(0xa1b2c3d4, 0xffffffff, 0x77777777)
e.packet.decoded.portnum = portnums_pb2.TEXT_MESSAGE_APP
e.packet.decoded.payload = "Line one\nLine two".encode()
save("text_multiline.pb", e)

# 8. Environment telemetry (unencrypted)
e = envelope(0x0badcafe, 0xffffffff, 0x88888888)
t = telemetry_pb2.Telemetry(time=1790000000)
em = t.environment_metrics
em.temperature = 23.5
em.relative_humidity = 61.2
em.barometric_pressure = 1012.3
em.lux = 350.0
em.wind_direction = 270
e.packet.decoded.portnum = portnums_pb2.TELEMETRY_APP
e.packet.decoded.payload = t.SerializeToString()
save("telemetry_env.pb", e)

# 9. Air quality telemetry (renamed keys pm10/pm25/pm100), encrypted
e = envelope(0x0badcafe, 0xffffffff, 0x99999999)
t = telemetry_pb2.Telemetry(time=1790000000)
aq = t.air_quality_metrics
aq.pm10_standard = 12
aq.pm25_standard = 18
aq.pm100_standard = 25
aq.co2 = 650
encrypt(e, mesh_pb2.Data(portnum=portnums_pb2.TELEMETRY_APP, payload=t.SerializeToString()))
save("telemetry_air_encrypted.pb", e)

# 10. Power telemetry (renamed keys voltage_ch1/current_ch1)
e = envelope(0xa1b2c3d4, 0xffffffff, 0xaaaaaaaa)
t = telemetry_pb2.Telemetry(time=1790000000)
t.power_metrics.ch1_voltage = 12.6
t.power_metrics.ch1_current = 0.35
t.power_metrics.ch2_voltage = 5.02
e.packet.decoded.portnum = portnums_pb2.TELEMETRY_APP
e.packet.decoded.payload = t.SerializeToString()
save("telemetry_power.pb", e)

# 11. Host telemetry (uint64 values, load in hundredths, string)
e = envelope(0xa1b2c3d4, 0xffffffff, 0xbbbbbbbb)
t = telemetry_pb2.Telemetry(time=1790000000)
hm = t.host_metrics
hm.uptime_seconds = 86400
hm.freemem_bytes = 6_000_000_000
hm.diskfree1_bytes = 120_000_000_000
hm.load1 = 152
hm.load5 = 98
hm.load15 = 75
hm.user_string = "meshtasticd on Pi"
e.packet.decoded.portnum = portnums_pb2.TELEMETRY_APP
e.packet.decoded.payload = t.SerializeToString()
save("telemetry_host.pb", e)

# --- Step 5 types ---
from meshtastic.protobuf import paxcount_pb2, remote_hardware_pb2

def plain(name, e, portnum, payload, request_id=0):
    e.packet.decoded.portnum = portnum
    e.packet.decoded.payload = payload
    if request_id:
        e.packet.decoded.request_id = request_id
    save(name, e)

# 12. Waypoint with an emoji icon, expiry and lock
wp = mesh_pb2.Waypoint(id=4242, latitude_i=223000000, longitude_i=1141700000, expire=1790086400,
                       locked_to=0xa1b2c3d4, name="Base camp", description="Meet here at 9", icon=0x1F3D5)
plain("waypoint.pb", envelope(0xa1b2c3d4, 0xffffffff, 0xcccccccc), portnums_pb2.WAYPOINT_APP, wp.SerializeToString())

# 13. NeighborInfo with 2 neighbors, encrypted
ni = mesh_pb2.NeighborInfo(node_id=0x0badcafe, last_sent_by_id=0x0badcafe, node_broadcast_interval_secs=900)
ni.neighbors.add(node_id=0xa1b2c3d4, snr=6.25)
ni.neighbors.add(node_id=0x12345678, snr=-3.5)
e = envelope(0x0badcafe, 0xffffffff, 0xdddddddd)
encrypt(e, mesh_pb2.Data(portnum=portnums_pb2.NEIGHBORINFO_APP, payload=ni.SerializeToString()))
save("neighborinfo_encrypted.pb", e)

# 14. Traceroute reply: !12345678 traced !0badcafe via !a1b2c3d4 (reply goes 0badcafe -> 12345678)
rd = mesh_pb2.RouteDiscovery(route=[0xa1b2c3d4], snr_towards=[25, 18], route_back=[0xa1b2c3d4], snr_back=[22, 30])
plain("traceroute_reply.pb", envelope(0x0badcafe, 0x12345678, 0xeeeeeeee), portnums_pb2.TRACEROUTE_APP,
      rd.SerializeToString(), request_id=0x13572468)

# 15. Traceroute request (no request_id)
rd = mesh_pb2.RouteDiscovery(route=[0xa1b2c3d4], snr_towards=[25])
plain("traceroute_request.pb", envelope(0x12345678, 0x0badcafe, 0xffff0001), portnums_pb2.TRACEROUTE_APP, rd.SerializeToString())

# 16. Paxcounter
pc = paxcount_pb2.Paxcount(wifi=17, ble=42, uptime=7200)
plain("paxcounter.pb", envelope(0x0badcafe, 0xffffffff, 0xffff0002), portnums_pb2.PAXCOUNTER_APP, pc.SerializeToString())

# 17. Detection sensor (plain text)
plain("detection.pb", envelope(0x0badcafe, 0xffffffff, 0xffff0003), portnums_pb2.DETECTION_SENSOR_APP, b"Motion detected")

# 18. Remote hardware: GPIO read reply
hw = remote_hardware_pb2.HardwareMessage(type=remote_hardware_pb2.HardwareMessage.Type.READ_GPIOS_REPLY,
                                         gpio_mask=0x30, gpio_value=0x10)
plain("remote_hardware.pb", envelope(0x0badcafe, 0x12345678, 0xffff0004), portnums_pb2.REMOTE_HARDWARE_APP, hw.SerializeToString())

# --- Step 6 edge cases (JSON rules) ---
def bare_envelope(from_node, to_node, packet_id):
    # no gateway_id (sender falls back to !from), no hop_start / rssi / snr (those keys are omitted)
    e = mqtt_pb2.ServiceEnvelope(channel_id="LongFast")
    p = e.packet
    setattr(p, "from", from_node)
    p.to = to_node
    p.id = packet_id
    p.rx_time = 1790000000
    p.hop_limit = 3
    return e

# 19. Non-ASCII, quotes, backslash, tab, emoji -> \u escapes and surrogate pairs
plain("text_unicode.pb", bare_envelope(0xa1b2c3d4, 0xffffffff, 0x01010101), portnums_pb2.TEXT_MESSAGE_APP,
      'Café ☕ "quoted" \\ tab\there 🏕'.encode())

# 20. Text that is JSON: passed through, re-serialized with sorted keys
plain("text_json.pb", envelope(0xa1b2c3d4, 0xffffffff, 0x02020202), portnums_pb2.TEXT_MESSAGE_APP,
      b'{"b": 1.0, "a": [true, null, "x\\u00e9"], "n": 42, "z": {"y": 2, "x": -0.5}}')

# 21. Text that is a bare number: json.loads gives 42, so payload is 42
plain("text_number.pb", envelope(0xa1b2c3d4, 0xffffffff, 0x03030303), portnums_pb2.TEXT_MESSAGE_APP, b"42")

# 22. Device telemetry with no values: voltage/channel_utilization/air_util_tx/uptime always emitted (defaults)
e = envelope(0xa1b2c3d4, 0xffffffff, 0x04040404)
t = telemetry_pb2.Telemetry(time=1790000000)
t.device_metrics.SetInParent()
plain("telemetry_device_empty.pb", e, portnums_pb2.TELEMETRY_APP, t.SerializeToString())

# 23. Tiny and large floats: scientific notation and fixed
e = envelope(0xa1b2c3d4, 0xffffffff, 0x05050505)
t = telemetry_pb2.Telemetry(time=1790000000)
t.power_metrics.ch1_current = 0.00001
t.power_metrics.ch1_voltage = 123456.7
t.power_metrics.ch2_current = -0.0
plain("telemetry_tiny.pb", e, portnums_pb2.TELEMETRY_APP, t.SerializeToString())

# 24. Traceroute reply with whole-number SNRs (6.0) and the "unknown" value -128 (-32.0)
rd = mesh_pb2.RouteDiscovery(route=[], snr_towards=[24], route_back=[], snr_back=[-128])
plain("traceroute_reply2.pb", envelope(0x0badcafe, 0x12345678, 0x06060606), portnums_pb2.TRACEROUTE_APP,
      rd.SerializeToString(), request_id=0x24681357)

# --- Channel keys (step 7): test channels configured in Window1's connect button ---
import base64
from functools import reduce
TEAM_KEY = bytes.fromhex("3a7b1c9e5d2f4a6b8c0d1e2f3a4b5c6d")                                   # AES-128
PRIVATE_KEY = bytes.fromhex("9f8e7d6c5b4a39281706f5e4d3c2b1a0112233445566778899aabbccddeeff00")  # AES-256

def channel_hash(name, key):
    x = lambda b: reduce(lambda a, c: a ^ c, b, 0)
    return x(name.encode()) ^ x(key)

def encrypt_with(e, data, key):
    import subprocess
    nonce = struct.pack("<I", e.packet.id) + bytes(4) + struct.pack("<I", getattr(e.packet, "from")) + bytes(4)
    e.packet.encrypted = subprocess.run(
        ["openssl", "enc", "-aes-%d-ctr" % (len(key) * 8), "-K", key.hex(), "-iv", nonce.hex()],
        input=data.SerializeToString(), capture_output=True, check=True).stdout

def channel_envelope(channel_id, from_node, packet_id, hash_name, key):
    e = envelope(from_node, 0xffffffff, packet_id)
    e.channel_id = channel_id
    e.packet.channel = channel_hash(hash_name, key)
    return e

# 25. Team channel (AES-128): matched by name and hash
e = channel_envelope("Team", 0xa1b2c3d4, 0x07070701, "Team", TEAM_KEY)
encrypt_with(e, mesh_pb2.Data(portnum=portnums_pb2.TEXT_MESSAGE_APP, payload=b"Team meeting at noon"), TEAM_KEY)
save("chan_team.pb", e)

# 26. Private channel (AES-256): matched by name and hash
e = channel_envelope("Private", 0x0badcafe, 0x07070702, "Private", PRIVATE_KEY)
pos = mesh_pb2.Position(latitude_i=223300000, longitude_i=1141800000, altitude=120, time=1790000000)
encrypt_with(e, mesh_pb2.Data(portnum=portnums_pb2.POSITION_APP, payload=pos.SerializeToString()), PRIVATE_KEY)
save("chan_private_aes256.pb", e)

# 27. Unknown channel_id, but the hash is Team's: found by hash only
e = channel_envelope("Elsewhere", 0xa1b2c3d4, 0x07070703, "Team", TEAM_KEY)
encrypt_with(e, mesh_pb2.Data(portnum=portnums_pb2.TEXT_MESSAGE_APP, payload=b"Found by hash"), TEAM_KEY)
save("chan_hash_only.pb", e)

# 28. A key nobody configured: not decrypted, hash shown
OTHER_KEY = bytes.fromhex("00112233445566778899aabbccddeeff")
e = channel_envelope("Secret", 0xa1b2c3d4, 0x07070704, "Secret", OTHER_KEY)
encrypt_with(e, mesh_pb2.Data(portnum=portnums_pb2.TEXT_MESSAGE_APP, payload=b"You can't read this"), OTHER_KEY)
save("chan_unknown_key.pb", e)
