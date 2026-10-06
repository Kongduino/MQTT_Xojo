# MQTT_Xojo: Meshtastic over MQTT in pure Xojo

A small MQTT 3.1.1 client and a Meshtastic toolkit, written entirely in Xojo with no plugins or external libraries, plus an example desktop app that uses them.

- **Uplink (mesh → JSON):** receives Meshtastic protobuf packets from `…/2/e/<channel>/<gateway>`, decrypts them with your channel keys, decodes them, and republishes them on `…/2/json/<channel>/<gateway>`. The JSON is byte-identical to the official [Meshtastic MQTT converter](https://github.com/caveman99/meshtastic-mqtt-converter) (the replacement for the JSON output the firmware used to have).
- **Downlink (JSON → mesh):** turns converter-style `{"type":"sendtext", …}` requests, or a message typed in the window, into protobuf packets a gateway accepts, sent as a *virtual node* with its own name. Direct messages are sent **PKI-encrypted** (Curve25519 + AES-256-CCM), as current firmware requires.

Both directions have been tested on real hardware: a STATION_G2 gateway on firmware 2.8.1, delivering to other nodes over LoRa.

Repository: <https://github.com/Kongduino/MQTT_Xojo>

## Contents

- [How it works](#how-it-works)
- [Features](#features)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Configuration](#configuration-mqtt_xojoconfigjson)
- [Sending into the mesh](#sending-into-the-mesh)
- [Troubleshooting](#troubleshooting)
- [Using the library in your own project](#using-the-library-in-your-own-project)
- [Repository layout](#repository-layout)
- [Test tools](#test-tools-testdata)
- [Limitations](#limitations)
- [Credits](#credits) and [License](#license)

## How it works

```
 Meshtastic nodes ──LoRa── gateway ──MQTT──▶ broker ──▶ MQTT_Xojo
                                                          │  decrypt (channel key or PKI), decode
                                                          ├─▶ one line per packet in the window
                                                          └─▶ <root>/2/json/<channel>/<gateway>  (converter JSON)

 window "Send" row, or JSON request ──▶ MQTT_Xojo ──▶ <root>/2/e/<channel or PKI>/<virtual node>
                                                       │ encrypted protobuf, sent as the virtual node
                                          broker ──▶ gateway (downlink enabled) ──LoRa──▶ nodes
```

## Features

- **MQTT client** (`MQTTClient`, an `SSLSocket` subclass): CONNECT with username and password, optional **TLS 1.2 / 1.3** (encryption only, see [Limitations](#limitations)), keep-alive with a watchdog that notices silent network drops, **automatic reconnect** with back-off, SUBSCRIBE / UNSUBSCRIBE, incoming QoS 0/1/2, outgoing PUBLISH at QoS 0 or **QoS 1** (confirmed by the broker, sent again after a reconnect). It disconnects with a clear message if the server doesn't answer like an MQTT broker. It doesn't depend on any window: everything reaches your code through events.
- **Protobuf reader and writer** (`ProtoReader`, `ProtoWriter`): varints including 10-byte negative int32, fixed32 / sfixed32, floats, strings, embedded messages, packed and unpacked repeated fields, and unknown-field skipping. Every read is bounds-checked, so garbage from a wrong key can't crash the parser.
- **Channel encryption:** AES-128/256-CTR through Xojo's `Crypto` module, with the firmware's nonce. Keys are expanded from PSKs exactly as the firmware does it, and the right key is found by channel name and **channel hash**.
- **Decoders:** text, position, nodeinfo, telemetry (device, environment, air quality, power, local stats, health, host), waypoint, neighbor info, traceroute, paxcounter, detection sensor and remote hardware. Hardware model and role names are included.
- **JSON in the converter's format:** a dedicated serializer gives keys sorted by code point and `ensure_ascii` escapes. Floats print like Python's `repr()` (`4.050000190734863`, `350.0`, `1e-05`), using an exact shortest round-trip algorithm checked against `repr()` on 755,000 values.
- **PKI direct messages:** X25519 in pure Xojo (a TweetNaCl port, RFC 7748 vectors), AES-256-CCM built on Xojo's AES, and the firmware's PKI nonce and key derivation. Recipients' public keys come from the config or are learned from NodeInfo packets. PKI messages to or from the virtual node are decrypted for display, but never republished as JSON.
- **Example app:**
  - one line per packet, and the JSON republished
  - a **Connect / Disconnect** button, and a Send row (To, channel, message)
  - **Clear**, and **Save logs**: saves the log to a file you choose, named with the date and time, with a header giving the span it covers (since the window opened or the last Clear)
  - duplicate filtering and an optional hex dump
  - all settings in an external JSON file that stays out of the repository
- **Direct connection to a node** (`MeshDeviceLink`): talks to a Meshtastic device over its client API, by **TCP** (port 4403, for nodes on WiFi or Ethernet) or **USB serial**, the protocol the Meshtastic apps and the Python CLI use. It asks the node for its configuration, keeps the connection open with a heartbeat, and passes on every packet the node delivers, already decrypted by the node. Each packet comes as a ServiceEnvelope, so `MeshPacketSummary` decodes it exactly like an MQTT message, JSON included. No MQTT broker is needed for this.
- **Self-tests at startup:** AES-128/256-CTR, JSON float formatting, X25519 and AES-CCM.

## Requirements

- Xojo **2026r2.1** (desktop). It uses `Crypto.AESDecrypt` with `BlockModes.CTR`, `Crypto.SHA2_256`, `JSONItem`, `RegEx` and `DesktopWindow.AddControl`. Older releases may work if they have those.
- The library (not the example app) also compiles for **Android** with Xojo 2026r2.1. See [On Android](#on-android).
- An MQTT broker that your Meshtastic gateway(s) also use.
- For the test tools (optional): Python 3 with the `meshtastic` package, `mosquitto_pub` / `mosquitto_sub`, `openssl`, and `cryptography` for the PKI checks.

## Quick start

1. Open `MQTT_Xojo.xojo_project` in Xojo.
2. Copy `MQTT_Xojo.config.example.json` to **`MQTT_Xojo.config.json`**, next to the project, and fill it in (see below). This file holds your password and keys, so `.gitignore` keeps it out of the repository.
3. Run the app and click **Connect**. The first lines confirm the setup:

```
Configuration: /path/to/MQTT_Xojo.config.json
TCP connection open, sending CONNECT
Connected. Subscribing to msh/EU_868/2/e/# (packetID 1)
AES-CTR self-test OK (raw key, output 40 bytes), AES-256 OK
JSON float self-test OK (27 values)
Channel "LongFast": AES-128, hash 8
Node !00c0ffee "Xojo MQTT" (XOJO): sending enabled
PKI self-test OK (X25519 RFC 7748, AES-256-CCM)
PKI on: public key …, 1 recipient key(s) known
  NodeInfo -> msh/EU_868/2/e/LongFast/!00c0ffee
```

After that you get one line per packet, plus the JSON republished for it:

```
!a1b2c3d4 -> ^all  port 1 TEXT_MESSAGE_APP (decrypted)  [LongFast via !deadbeef]  "Hello"
  JSON -> msh/EU_868/2/json/LongFast/!deadbeef: {"channel":8,"from":2712847316,…,"type":"text"}
!a1b2c3d4 -> ^all  port 67 TELEMETRY_APP (decrypted)  [LongFast via !deadbeef]  device: battery_level 87, voltage 4.05, …
```

The app looks for `MQTT_Xojo.config.json` next to itself and in up to six parent folders, so it finds it from the debug run and from a build in `Builds - MQTT_Xojo/<platform>/`. The file is read again at every connect, so edits only need a reconnect, not a rebuild.

## Configuration (`MQTT_Xojo.config.json`)

```json
{
  "broker":   { "host": "mqtt.example.com", "port": 1883, "tls": false, "username": "…", "password": "…", "client_id": "MQTT_Xojo" },
  "topics":   ["msh/EU_868/2/e/#", "msh/EU_868/2/json/#"],
  "channels": [ { "name": "LongFast", "psk": "AQ==" },
                { "name": "MyChannel", "psk": "base64 PSK from the Meshtastic app" } ],
  "options":  { "dedupe": true, "hexdump": false, "reconnect": true, "send_qos": 1, "json_qos": 0 },
  "node":     { "id": "!00c0ffee", "long_name": "Xojo MQTT", "short_name": "XOJO",
                "root": "msh/EU_868", "private_key": "base64, 32 bytes" },
  "public_keys": { "!aabbccdd": "base64 public key of a node you want to DM" }
}
```

| Key | Meaning |
|---|---|
| `broker` | Broker connection. Username and password are optional. `tls`: connect with TLS (default false). `tls_version`: `"1.2"` (default), `"1.3"`, or `"auto"` (negotiates the best version, but also allows outdated ones). `port` defaults to 8883 with TLS, 1883 without. |
| `topics` | Subscriptions. Subscribe to `…/2/json/#` too if you want to send through JSON requests. |
| `channels` | Channel **name as in the topic** (e.g. `LongFast`) and its PSK, as the Meshtastic app shows it (base64). `0x…`, plain hex, `base64:…`, `default` and `none` also work. Short keys are zero-padded like the firmware does. |
| `options.dedupe` | Show and republish each packet (sender + id) only once per 10 minutes. Off by default, like the converter, which republishes every copy a gateway sends. |
| `options.hexdump` | Hex dump of every raw MQTT read. Off by default. |
| `options.send_qos` / `options.json_qos` | QoS of what the app publishes: your sends and the NodeInfo (`send_qos`, default 1), and the JSON republished for every received packet (`json_qos`, default 0). With QoS 1 the broker confirms each message (`SEND confirmed by the broker (packet N)`). Messages it hasn't confirmed are sent again after a reconnect, and reported as not delivered if the connection ends for good. The confirmation means **the broker** has the message, not that a node received it. |
| `options.reconnect` | Reconnect automatically when the connection is lost or the first attempt fails (default on). The back-off is 2, 4, 8 … up to `reconnect_max_delay` seconds (default 60), with ±20% jitter, giving up after `reconnect_give_up` seconds (default 900, i.e. 15 minutes). There are no retries after a refused login (except "server unavailable"), a failed TLS handshake, a server that isn't an MQTT broker, or a click on Disconnect. After a reconnect, the subscriptions are renewed and the NodeInfo is resent at most once an hour. |
| `node` | Optional. **Enables sending.** `id` is the virtual node's number (pick one no real node uses), and `root` is the topic root for its NodeInfo and messages. |
| `node.private_key` | Optional. Enables PKI direct messages. If it's missing, the app prints a fresh random key to paste in. **Never change it once nodes have seen it:** nodes pin the first public key they learn for a node and drop NodeInfo with a different one. |
| `public_keys` | Recipients for PKI DMs. Keys are also learned automatically from NodeInfo packets the app sees. |

## Sending into the mesh

**From the window:** type in the Send row. Leave *To* empty for a broadcast on the selected channel, or enter `!aabbccdd` for a direct message. A DM goes PKI-encrypted when the recipient's public key is known. Press Return or click Send.

**Through MQTT:** publish a request to `<root>/2/json/<channel>/<anything>`, in the same format the converter accepts:

```bash
mosquitto_pub -h … -t "msh/EU_868/2/json/LongFast/me" -m '{"type":"sendtext","payload":"Hello mesh"}'
mosquitto_pub -h … -t "msh/EU_868/2/json/LongFast/me" -m '{"type":"sendtext","to":"!aabbccdd","payload":"Just you"}'
mosquitto_pub -h … -t "msh/EU_868/2/json/LongFast/me" -m '{"type":"sendposition","payload":{"latitude":50.7753,"longitude":6.0839,"altitude":200}}'
```

- `sendtext`: `payload` is a string, or `{"text": …}`.
- `sendposition`: `latitude` / `longitude` in degrees, or `latitude_i` / `longitude_i` (1e-7 degrees, which take precedence), plus `altitude` and `time`.
- Optional fields:
  - `to` (a number or `"!aabbccdd"`; broadcast if omitted)
  - `want_ack` (default true for direct messages, ignored for broadcasts): ask the destination node for a delivery confirmation
  - `from` (defaults to the virtual node)
  - `id` (random if omitted)
  - `hopLimit` / `hop_limit` (0–7, default 3)
  - `channel_id`, `gateway_id`
  - `pki` (`true` / `false` to force the encryption mode)
- The packet is published on `<root>/2/e/<channel>/<node id>`, or `<root>/2/e/PKI/<node id>` for PKI DMs. The window shows `SEND -> topic: …` or `SEND failed: <reason>`.
- JSON whose `type` doesn't start with `send` (including the app's own uplink JSON) is ignored, so there's no loop.

**Delivery confirmation:** a direct message asks the destination node for an acknowledgement (Meshtastic `want_ack`). The log then shows `DELIVERED: DM to !aabbccdd acknowledged by !aabbccdd`, or `NOT DELIVERED: … NO_ROUTE (reported by !…)` with the firmware's reason, or `No acknowledgement … within 2 minutes`. In the other direction, when a node DMs the virtual node with `want_ack`, the app answers with an ACK, like a node does (`ACK sent to !aabbccdd`).

### What a gateway needs to accept downlink

These rules come from the firmware's `MQTT.cpp` and `Router.cpp`. Each one silently drops packets if it isn't met:

- **Downlink enabled** on the channel. **Reboot the gateway** (or reconnect its MQTT) after enabling it: it only subscribes to `<root>/2/e/<channel>/+` when it connects.
- `packet.from` and the envelope's `gateway_id` must **not** be the gateway's own. That's why the app sends as a virtual node.
- With **MQTT encryption enabled** on the gateway, decoded (plaintext) packets are ignored. Packets must be encrypted, with the **channel hash** in `packet.channel`. The converter's commented-out downlink code misses this and also uses a different nonce for encryption than for decryption; this implementation follows the firmware.
- **Ignore MQTT** (`lora.ignore_mqtt`) must be off on the gateway and on the receivers. The firmware turns it on by default in duty-cycle regions such as EU_868.
- Channel-encrypted text **direct messages are rejected** ("Rejecting legacy DM") unless the owner is a licensed (ham) user, so DMs must be PKI. For PKI DMs, the gateway must know both nodes (NodeInfo), and the recipient must have the virtual node's public key, which the app announces in its NodeInfo at connect.
- Nodes drop any (sender, id) pair they have seen recently, so use fresh packet ids when testing.

## Troubleshooting

| You see | What it means |
|---|---|
| `MQTT_Xojo.config.json not found …` | The config isn't next to the app or in its parent folders. Copy the example file next to the project. |
| `Connection lost (…). Reconnecting in N s` / `Attempt K failed …` | The connection dropped and the app is retrying. Click **Disconnect** to stop. `error 49: network unavailable` means no usable network (e.g. Wi-Fi off). |
| `Gave up reconnecting …` | No connection for `reconnect_give_up` seconds. Click **Connect** to start again. |
| `The broker refused the connection: … (code N)` | The broker rejected the login. Code 5 (not authorized) or 4 (bad username or password): check `username` / `password` and the broker's access rules. |
| `Socket error 303: TLS handshake failed …` | `tls` is on, but the server refused the secure connection or doesn't speak TLS on that port (check the port: usually 8883 for TLS). |
| `The server did not answer with an MQTT CONNACK …` | Something answered on that host and port, but it isn't an MQTT broker (e.g. a web server). |
| `Invalid JSON …`, `Incomplete configuration …`, `Invalid PSK for channel(s) …` | The message names the file and what's wrong in it. |
| `encrypted (N bytes, channel hash H, no matching key)` | No configured channel has hash H. Compare H with the hashes in the `Channel "…"` lines at connect: a different hash means the name or the PSK doesn't match the node's channel. |
| `PKI direct message (N bytes, needs the recipient's private key)` | A DM between two other nodes. Only the recipient can read it. |
| `PKI direct messages off: add "private_key": …` | Paste the suggested key into `node.private_key` (once, and keep it). |
| `SEND failed: no public key known for !…` | Add the node to `public_keys`, or wait until its NodeInfo has passed through. |
| A self-test line says `FAILED` | The line names the failing part. Please open an issue with it and your Xojo version. |
| Sending works on MQTT but nodes get nothing | See the gateway rules above. Most often: Downlink enabled without a gateway reboot, or Ignore MQTT on. |

## Using the library in your own project

Copy the files in `Library/` into your project (drag them into the Xojo navigator). For a complete application built on the library, see [Sensor_Dashboard](https://github.com/Kongduino/Sensor_Dashboard): it follows sensors over MQTT and over a node's TCP or USB connection.

| Item | Purpose |
|---|---|
| `MQTTClient` | MQTT 3.1.1 client (class, `SSLSocket` subclass) |
| `ProtoReader`, `ProtoWriter` | Protobuf wire format (class / module) |
| `Curve25519` | X25519 (module) |
| `MeshDecode` | Packet decoding and summaries, names, `MeshSeenRecently` |
| `MeshJSON` | Converter-format JSON, Python-identical float formatting |
| `MeshChannels` | Channel table, PSK parsing, channel hash, channel decryption |
| `MeshCrypto` | AES-CTR / CCM, PKI, key store, self-tests |
| `MeshSend` | Downlink: envelopes, NodeInfo, JSON requests |
| `MeshDeviceLink` | A node over TCP or USB serial, through its client API (class) |
| `USBSerial` | A USB serial port on Android, through usb-serial-for-android; used by `MeshDeviceLink.ConnectUSB` (class) |

`MQTTClient` methods:
- `SetCredentials(user, password)` and `SetTLS(enabled, connectionType)`
- `SetAutoReconnect(enabled, maxDelaySeconds, giveUpAfterSeconds)` (off by default) and `IsReconnecting`
- `PublishQoS1(topic, payload, retain) As Integer` (returns the packet ID) and `PendingCount`
- `ErrorDescription(err)`, a readable socket error
- `Connect(host, port, clientID, keepAliveSeconds, cleanSession)`
- `Subscribe(topic, qos) As Integer` and `Unsubscribe(topic)`
- `Publish(topic, payload, retain)`
- `Disconnect`
- `IsMQTTConnected`

Events:
- `MQTTConnected(sessionPresent)`, `MQTTConnectionRefused(reasonCode)` and `MQTTDisconnected`
- `MessageReceived(topic, payload, qos, retained)`
- `Subscribed(packetID, grantedQoS())` and `Unsubscribed(packetID)`
- `SocketError(err)`
- `Reconnecting(attempt, delaySeconds, reason)` and `ReconnectFailed(reason)`
- `PublishAcknowledged(packetID)` and `PublishFailed(packetID, reason)`
- `Trace(message)` and `RawDataReceived(data)`

A minimal Meshtastic receiver:

```xojo
// once, before connecting
Call MeshAddChannel("LongFast", "AQ==")

// in MQTTClient.MessageReceived
Dim jsonText, packetKey As String
Dim summary As String = MeshPacketSummary(payload, jsonText, packetKey)
If summary <> "" Then
  // summary: "!a1b2c3d4 -> ^all  port 1 TEXT_MESSAGE_APP (decrypted)  [LongFast via !deadbeef]  ""Hello"""
  // jsonText: the converter's JSON ("" for packets it doesn't convert)
End If
```

`MeshLastPacketRadio(hops, hopStart, relayNode, viaMQTT)`, called right after `MeshPacketSummary`, says how that packet reached the gateway (or the connected node): `hops` is 0 for a packet heard directly and −1 when unknown (firmware before 2.3), `relayNode` is the last byte of the node that transmitted it last: the relay, or the sender itself for a direct packet (0 when unknown; firmware 2.6+), and `viaMQTT` is True when the gateway got it from MQTT rather than by radio. The packet's RSSI / SNR describe the link to the sender only when `hops` is 0 and `viaMQTT` is False. These values stay out of the JSON, which remains identical to the converter's.

`MeshLastPacketSignal(fromNode, packetID, rssi, snr)`, also called right after `MeshPacketSummary`, gives the packet's sender, id and reception (RSSI / SNR as the gateway or node reported them, 0 when absent). It works for packets that couldn't be decrypted too, so a packet can be matched by its id without its key.

Sending:
- `MeshDownlink(topic, json, fromNode, gatewayID, outTopic, outPayload, info)` turns a JSON request into a packet to publish.
- `MeshBuildEnvelope` and `MeshNodeInfoPayload` build packets directly.
- For PKI, call `MeshSetPKIIdentity(nodeNum, privateKey)` and `MeshSetPublicKey(nodeNum, key)`.
- `MeshCryptoSelfTest`, `MeshJSONSelfTest` and `MeshPKISelfTest` return a status line you can show at startup.

### On Android

The same `Library/` files work in a Xojo Android project; they're tested on a phone with MQTT, a node over TCP, and channel decryption. A few things differ:

- **AES:** Android's `Crypto` module has no AES, so `MeshAESCTR` uses `MeshAESCTRXojo`, an AES-CTR written in plain Xojo. On desktop, `MeshCryptoSelfTest` also runs it against the same known answers and reports `Xojo AES OK`.
- **USB serial:** Android has no `SerialConnection`, so `MeshDeviceLink.ConnectSerial` exists only on desktop and console. On Android, `ConnectUSB(deviceName)` goes through `USBSerial`, built on [usb-serial-for-android](https://github.com/mik3y/usb-serial-for-android) (MIT; CDC-ACM boards such as nRF52, RP2040 and ESP32-S3, and CP210x, CH34x, FTDI and PL2303 chips). Add its Gradle dependency in Build Settings → Android → Dependencies: `com.github.mik3y:usb-serial-for-android:3.11.0`. Android asks the user to allow the device, again each time it's plugged in: `ConnectUSB` asks, reports it through `LinkClosed`, and the next `ConnectUSB` connects once allowed. To skip that question, add the dependency `com.github.Kongduino:XojoUsbAttach:1.0.0` as well ([XojoUsbAttach](https://github.com/Kongduino/XojoUsbAttach)): plugging a known device in then opens the app with the permission granted (choose **Always** the first time). `USBSerial` also works on its own for any USB serial device; it's published separately, with an example app, as [XojoAndroidUSBSerial](https://github.com/Kongduino/XojoAndroidUSBSerial) (`Devices`, `HasPermission`, `RequestPermission`, `Open`, `Write`, `DataAvailable`). On desktop it compiles but does nothing.
- **Binary Strings:** on Android, a String built by concatenation is tagged UTF-8, and its byte functions (`Bytes`, `MiddleBytes`, `AscByte`, socket `Write`) then count each byte from 128 to 255 as two. The library keeps binary data tagged one byte per character with `MeshBin(s)`, and decodes UTF-8 bytes into text with `MeshUTF8Text(bytes)`. On desktop, `MeshBin` returns its argument unchanged, and `MeshUTF8Text` is `DefineEncoding(Encodings.UTF8)`.
- **ByRef:** in Xojo's translation to Kotlin, a ByRef parameter passed on to another method's ByRef parameter doesn't get the value back, without any error. The library always goes through a local variable (`MeshParsePSK` used to return an empty key, so no channel packet decrypted on Android); do the same in your own code.
- **Node numbers above 2³¹:** a UInt32 from a packet is sign-extended when widened, so a node number read from a packet and the same one made from a hex string (`!aabbccdd`) can compare as different. Compare them as `Int64` values corrected to positive (add 2³² when negative), and print ids the same way.
- **`MessageReceived` payload:** on Android it's the raw bytes, so `MeshPacketSummary(payload, …)` works directly. For a text or JSON payload, use `MeshUTF8Text(payload)`. If you build binary data yourself by concatenation, pass it through `MeshBin` before `Publish`.

### A node over TCP or USB (`MeshDeviceLink`)

Methods:
- `ConnectTCP(host, port)` (port 4403 by default), `ConnectSerial(device As SerialDevice)` (115200 baud; desktop and console) or `ConnectUSB(deviceName)` (Android, 115200 baud; "" for the first USB serial device; see On Android)
- `Close`, which tells the node the client is leaving
- `IsOpen`, `IsConfigured`, `MyNodeNum`, `MyNodeID`, `LongName` and `ShortName`
- `NodeCount`, `NodeNumAt(i)`, `NodeLongNameAt(i)` and `NodeShortNameAt(i)`: the nodes the device knows (its NodeDB, sent with its configuration)
- `RequestPosition(toNode)`: asks a node for its GPS position through the device; the answer (a POSITION_APP packet) comes back through `PacketReceived`, or a ROUTING `NO_RESPONSE` when the node has no fix or doesn't share it
- `SendText(text, channelIndex, hopLimit, toNode)`: a text message (TEXT_MESSAGE_APP) the node sends as itself, to everyone by default, without ACK; returns its packet id. With `hopLimit` 0 (the default) only nodes in direct range get it, which is what a range test needs. The firmware refuses texts sent too close together with a ROUTING NAK `RATE_LIMIT_EXCEEDED` (see `MeshTakeRouting`)
- `RequestTelemetry(toNode, kind)`: asks a node for its telemetry through the device (`kind` 3 = environment, the default; 2 device, 4 air quality, 5 power) and returns the request's packet id. The answer is addressed to the device, which decrypts it and passes it on through `PacketReceived`; a node with nothing to send answers with a ROUTING `NO_RESPONSE` (see `MeshTakeRouting`)

Events:
- `LinkOpened`, then `ConfigComplete` once the node has sent its configuration (its node number and names are known from then on)
- `PacketReceived(envelope)`: every packet the node delivers, as a ServiceEnvelope for `MeshPacketSummary`
- `LinkClosed(reason)`: a TCP or serial error, such as the node rebooting or leaving WiFi
- `LogLine(text)`: the node's console text and log records

The link is created in code, so its events are connected with `AddHandler`:

```xojo
mLink = New MeshDeviceLink
AddHandler mLink.PacketReceived, WeakAddressOf LinkPacket   // Sub LinkPacket(sender As MeshDeviceLink, envelope As String)
AddHandler mLink.LinkClosed, WeakAddressOf LinkClosed       // Sub LinkClosed(sender As MeshDeviceLink, reason As String)
mLink.ConnectTCP("192.168.1.50")

// in LinkPacket
Dim jsonText, packetKey As String
Dim summary As String = MeshPacketSummary(envelope, jsonText, packetKey)
```

A node has a single outgoing queue for all its clients, so two connections to the same node (an app and this link, or two links) share its packets between them. While the link has the USB port open, no other program can use it.

## Repository layout

The project is in Xojo's text format: one file per class, module or window, so changes are easy to review and items are easy to reuse.

```
MQTT_Xojo.xojo_project          the project (open this in Xojo)
Library/                        the reusable library: copy these files into your own project
  MQTTClient.xojo_code            MQTT 3.1.1 client (SSLSocket subclass)
  ProtoReader.xojo_code           protobuf reader (class)
  ProtoWriter.xojo_code           protobuf writer (module)
  Curve25519.xojo_code            X25519
  MeshDecode.xojo_code            packet decoding, summaries, names, duplicate filter
  MeshJSON.xojo_code              converter-format JSON, Python-identical floats
  MeshChannels.xojo_code          channel table, PSKs, channel hash, channel decryption
  MeshCrypto.xojo_code            AES-CTR / CCM, PKI, key store, self-tests
  MeshSend.xojo_code              downlink: envelopes, NodeInfo, ACKs, JSON requests
  MeshDeviceLink.xojo_code        a node over TCP or USB serial (client API)
  USBSerial.xojo_code             a USB serial port on Android (usb-serial-for-android)
Example App/                    the example desktop app
  Window1.xojo_window             the window, its MQTTClient1 instance and the buttons
  AppConfig.xojo_code             reads MQTT_Xojo.config.json
  SendBox.xojo_code               the Send row (created in code)
  AppUtils.xojo_code              log, save, publish helpers, ACK tracking
App.xojo_code, MainMenuBar.xojo_menu, Build Automation.xojo_code
MQTT_Xojo.config.example.json   copy to MQTT_Xojo.config.json and fill in
testdata/                       test packets, the converter's reference JSON, and the test tools
LICENSE                         GPL-3.0
```

## Test tools (`testdata/`)

| Tool | What it checks |
|---|---|
| `make_testdata.py` | Builds 28 test packets with the official `meshtastic` protobufs: every payload type, encrypted ones, edge cases (unicode, JSON text, tiny floats, AES-256, channel hash only, unknown key). |
| `make_golden.py` | Runs the official converter's own `convert_to_json()` on them (`MQTT_CONVERTER=<path to the converter>`), giving `<name>.json`. |
| `publish_tests.sh` | Publishes all test packets to `<node.root>/2/e/LongFast/!deadbeef` (or `$TOPIC_ROOT`). |
| `compare_json.py [output]` | Compares the app's `JSON ->` lines in a saved output (newest `results/result*.txt` by default) with the converter's JSON. Expected: 26/26 identical. |
| `live_check.py <output>` | Rebuilds live packets from a hex-dump output (`hexdump: true`), runs the converter on them and compares. |
| `downlink_check.py` | Sends JSON requests, captures what the app publishes, and verifies it with the official protobufs and openssl. The DM test (to `$DM_TO` or the first `public_keys` entry) goes PKI and is decrypted independently by `pki_decrypt.py` (`cryptography`). |

The encrypted test packets use three test channels. Add them to your config while testing:

```json
{"name": "LongFast", "psk": "AQ=="}, {"name": "Team", "psk": "Onscnl0vSmuMDR4vOktcbQ=="},
{"name": "Private", "psk": "n459bFtKOSgXBvXk08KxoBEiM0RVZneImaq7zN3u/wA="}
```

A typical run:
1. Subscribe the app to `<root>/#` and connect.
2. Run `testdata/publish_tests.sh`.
3. Save the window's text to `results/result.txt`.
4. Run `python3 testdata/compare_json.py`.

## Limitations

- **TLS encrypts the connection but doesn't verify the broker's certificate.** Xojo's `SSLSocket` accepted a deliberately invalid certificate (self-signed.badssl.com) exactly like a valid one, and offers no way to check it. So TLS protects your password and traffic against eavesdropping, not against someone impersonating the broker. The app logs a note to that effect whenever TLS is on.
- MQTT: outgoing publishes at QoS 0 or 1 (no QoS 2). QoS 1 is "at least once": after a reconnect the broker may receive a message twice, which Meshtastic nodes ignore as a duplicate packet id. Messages sent while disconnected aren't queued (`SEND failed: not connected`).
- A QoS 1 confirmation only means the broker received the message. Whether the destination node got it comes from Meshtastic's own acknowledgement (`want_ack`, see [Sending into the mesh](#sending-into-the-mesh)), which only direct messages ask for.
- PKI DMs can only be read when they're to or from the virtual node, since only its private key is known.
- **Firmware 2.8 gateways don't upload PKI DMs to the virtual node.** The DM is relayed over LoRa, but never published to MQTT: 2.8 classifies a packet it can't decrypt as `OPAQUE_RELAY_ONLY` and relays it without handling it (`Router.cpp`, routing-auth verdict), so it never reaches the MQTT uplink. Firmware 2.7 uploaded these. This appears to be intentional in 2.8, as part of its packet-authenticity rules, at least for now: it isn't a bug in this library, and there is no workaround on the MQTT side. Sending DMs to the mesh, and their delivery ACKs, are not affected.
- JSON passthrough of text messages handles objects, arrays, numbers, `true`/`false`/`null`, but not a bare JSON string literal. A float inside such JSON that is smaller than about 0.01 with a full 53-bit mantissa falls back to Xojo's `ToString` instead of Python's exact formatting.
- Compressed text (portnum 7) isn't decoded, and the official converter doesn't decode it either.

## Credits

- [Meshtastic](https://meshtastic.org): firmware and protobufs (GPL-3.0). The protocol behaviour here follows the firmware source.
- [Meshtastic MQTT converter](https://github.com/caveman99/meshtastic-mqtt-converter) (GPL-3.0): the JSON format and the reference output for the tests.
- [TweetNaCl](https://tweetnacl.cr.yp.to) (public domain): the X25519 field arithmetic and ladder, ported to Xojo. [RFC 7748](https://www.rfc-editor.org/rfc/rfc7748) for the test vectors.
- AES-CCM follows Jouni Malinen's implementation used by the firmware (`aes-ccm.cpp`) and RFC 3610.

## License

Copyright © 2026 Kongduino.

GNU General Public License v3.0 or later. See [LICENSE](LICENSE).
