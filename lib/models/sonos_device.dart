/* Sonos Device model

   Represents a single Sonos speaker (a "ZonePlayer") discovered on the
   local network via SSDP.

   Sonos speakers are controlled over their local, undocumented UPnP
   API: SOAP-over-HTTP POST requests to port 1400 on the speaker's IP.
   The two pieces we need to talk to a speaker are therefore its [ip]
   (to build the control URL) and a stable [uuid] (to recognise the
   same speaker across re-discoveries and to tell whether the speaker
   the user tapped is the one we're currently connected to).

   [roomName] is the human-friendly name the user set in the Sonos app
   ("Living Room", "Keuken", ...) and is what we show in the device
   picker.

   This mirrors the shape of `GoogleCastDevice` from flutter_chrome_cast
   (which exposes `deviceID` + `friendlyName`) so both device types can
   be presented through the same UI with minimal special-casing.
*/

class SonosDevice {
  /// The speaker's IP address on the local network, e.g. `192.168.0.31`.
  final String ip;

  /// Stable unique id parsed from the SSDP `USN` header
  /// (e.g. `RINCON_XXXXXXXXXXXX01400`). Used for equality so the same
  /// speaker discovered twice doesn't appear as two entries.
  final String uuid;

  /// Friendly room name shown to the user. Falls back to the IP until
  /// the device description has been fetched.
  final String roomName;

  const SonosDevice({
    required this.ip,
    required this.uuid,
    required this.roomName,
  });

  /// The base URL for all SOAP control endpoints on this speaker.
  String get baseUrl => 'http://$ip:1400';

  SonosDevice copyWith({String? ip, String? uuid, String? roomName}) {
    return SonosDevice(
      ip: ip ?? this.ip,
      uuid: uuid ?? this.uuid,
      roomName: roomName ?? this.roomName,
    );
  }

  // Equality is based on the stable uuid, not the IP: a speaker that
  // gets a new DHCP lease is still the same speaker to the user.
  @override
  bool operator ==(Object other) => other is SonosDevice && other.uuid == uuid;

  @override
  int get hashCode => uuid.hashCode;

  @override
  String toString() => 'SonosDevice($roomName @ $ip / $uuid)';
}
