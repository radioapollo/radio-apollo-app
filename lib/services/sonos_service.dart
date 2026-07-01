/* Sonos Service

   Discovers and controls Sonos speakers on the local network.

   Why this exists / why it's hand-rolled
   ──────────────────────────────────────
   Sonos speakers do NOT speak the Chromecast protocol, so
   flutter_chrome_cast can never see or drive them. There is also no
   official or maintained Flutter/Dart Sonos SDK. The community-standard
   approach — used by node-sonos, SoCo, and every third-party Sonos app —
   is the speaker's local UPnP interface:

     • Discovery: an SSDP M-SEARCH UDP multicast to 239.255.255.250:1900
       asking for `ZonePlayer` devices. Each speaker answers with its
       location URL and a stable RINCON id.
     • Control:   SOAP-over-HTTP POST requests to port 1400 on the
       speaker (AVTransport for play/pause/stop/set-stream,
       RenderingControl for volume).

   This API is undocumented and unsupported by Sonos, but has been
   stable for years across S1 and S2. Service/action shapes here follow
   the community documentation at sonos.svrooij.io.

   Design parity with the Chromecast path
   ──────────────────────────────────────
   `GoogleCastDiscoveryManager` exposes a `devicesStream`; this service
   mirrors that with [devicesStream] so the device-picker UI can render
   Sonos speakers and Chromecasts through the same list. Control methods
   are deliberately shaped like simple awaitable futures that throw a
   human-readable message on failure, matching the defensive style of
   AdminModerationService / AppCheckHttp elsewhere in the app (timeouts,
   caught socket errors, Dutch-facing exception text).

   Singleton so discovery runs once and all callers share the same
   device list, exactly like the other *Service.instance classes.
*/

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/sonos_device.dart';

/// High-level transport state of a Sonos speaker, normalised from the
/// speaker's `GetTransportInfo` response so callers don't deal with raw
/// UPnP strings.
enum SonosPlaybackState { playing, paused, stopped, transitioning, unknown }

class SonosService {
  SonosService._();
  static final SonosService instance = SonosService._();

  // ── Tunables ──────────────────────────────────────────────────────────────

  static const _ssdpAddress = '239.255.255.250';
  static const _ssdpPort = 1900;
  static const _controlPort = 1400;

  /// How long a single discovery sweep listens for speaker replies.
  static const _discoveryWindow = Duration(seconds: 3);

  /// Per-request timeout for SOAP control calls. Speakers on a healthy
  /// LAN respond in well under a second; this is a generous ceiling so
  /// a hung speaker can't block the UI forever.
  static const _controlTimeout = Duration(seconds: 5);

  static const _avTransport = 'urn:schemas-upnp-org:service:AVTransport:1';
  static const _renderingControl =
      'urn:schemas-upnp-org:service:RenderingControl:1';

  // ── Discovered devices ─────────────────────────────────────────────────────

  final _devices = <String, SonosDevice>{}; // keyed by uuid
  final _devicesController = StreamController<List<SonosDevice>>.broadcast();

  /// Stream of currently-known Sonos speakers. Mirrors
  /// `GoogleCastDiscoveryManager.instance.devicesStream`.
  Stream<List<SonosDevice>> get devicesStream => _devicesController.stream;

  /// The most recent device list, for priming a StreamBuilder's
  /// `initialData` (same trick the Firestore-backed services use).
  List<SonosDevice> get devices => List.unmodifiable(_devices.values);

  // ── Injectable HTTP client (for tests, mirrors AppCheckHttp) ───────────────

  /// Override in tests with a MockClient. Production uses a real client.
  http.Client Function() clientFactory = http.Client.new;

  // ── Discovery ──────────────────────────────────────────────────────────────

  bool _discovering = false;

  /// Runs one SSDP discovery sweep and updates [devicesStream].
  ///
  /// Safe to call repeatedly (e.g. each time the user opens the device
  /// picker). Overlapping calls are coalesced — a second call while one
  /// is in flight just returns.
  Future<void> discover() async {
    if (kIsWeb) return; // no raw sockets on web
    if (_discovering) return;
    _discovering = true;

    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      ).timeout(const Duration(seconds: 2));

      socket.broadcastEnabled = true;

      final message =
          'M-SEARCH * HTTP/1.1\r\n'
          'HOST: $_ssdpAddress:$_ssdpPort\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 1\r\n'
          'ST: urn:schemas-upnp-org:device:ZonePlayer:1\r\n'
          '\r\n';

      final pending = <Future<void>>[];
      final seenLocations = <String>{};

      final done = Completer<void>();
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket!.receive();
        if (datagram == null) return;

        final response = String.fromCharCodes(datagram.data);
        final location = _headerValue(response, 'LOCATION');
        if (location == null || !seenLocations.add(location)) return;

        // Resolve the friendly room name in the background; don't block
        // the listen loop.
        pending.add(_addFromLocation(location, datagram.address.address));
      });

      // Send the search a couple of times — UDP is lossy and some
      // speakers answer only the second probe.
      socket.send(message.codeUnits, InternetAddress(_ssdpAddress), _ssdpPort);
      await Future.delayed(const Duration(milliseconds: 300));
      socket.send(message.codeUnits, InternetAddress(_ssdpAddress), _ssdpPort);

      // Listen for the discovery window, then wrap up.
      Timer(_discoveryWindow, () {
        if (!done.isCompleted) done.complete();
      });
      await done.future;
      await Future.wait(pending);
    } on TimeoutException {
      debugPrint('[SonosService] Discovery socket bind timed out');
    } catch (e) {
      debugPrint('[SonosService] Discovery failed: $e');
    } finally {
      socket?.close();
      _discovering = false;
    }
  }

  /// Fetches the device description at [location] to learn the room name
  /// and stable UUID, then adds/updates the device and emits.
  Future<void> _addFromLocation(String location, String fallbackIp) async {
    final client = clientFactory();
    try {
      final uri = Uri.parse(location);
      final ip = uri.host.isNotEmpty ? uri.host : fallbackIp;

      String roomName = ip;
      String uuid = 'RINCON_$ip';

      try {
        final resp = await client.get(uri).timeout(const Duration(seconds: 3));
        if (resp.statusCode == 200) {
          roomName =
              _tagValue(resp.body, 'roomName') ??
              _tagValue(resp.body, 'friendlyName') ??
              ip;
          uuid = _tagValue(resp.body, 'UDN')?.replaceFirst('uuid:', '') ?? uuid;
        }
      } catch (e) {
        // Description fetch failed; keep the IP-based fallbacks so the
        // speaker is still usable, just with a less friendly label.
        debugPrint('[SonosService] Description fetch failed for $ip: $e');
      }

      final device = SonosDevice(ip: ip, uuid: uuid, roomName: roomName);
      _devices[uuid] = device;
      _devicesController.add(devices);
    } finally {
      client.close();
    }
  }

  // ── Control: stream playback ───────────────────────────────────────────────

  /// Points the speaker at our live radio stream and starts playing.
  ///
  /// For an internet radio stream the Sonos-native URI form is the raw
  /// stream URL prefixed with `x-rincon-mp3radio://` (with the scheme
  /// stripped). This tells the speaker to treat it as a continuous
  /// radio stream rather than a finite track.
  Future<void> playStream(
    SonosDevice device, {
    required String streamUrl,
    String title = 'Radio Apollo',
  }) async {
    final radioUri = _toRadioUri(streamUrl);
    final metadata = _radioMetadata(title);

    await _soap(
      device,
      service: _avTransport,
      endpoint: '/MediaRenderer/AVTransport/Control',
      action: 'SetAVTransportURI',
      body:
          '<InstanceID>0</InstanceID>'
          '<CurrentURI>${_escape(radioUri)}</CurrentURI>'
          '<CurrentURIMetaData>${_escape(metadata)}</CurrentURIMetaData>',
    );

    await play(device);
  }

  Future<void> play(SonosDevice device) => _soap(
    device,
    service: _avTransport,
    endpoint: '/MediaRenderer/AVTransport/Control',
    action: 'Play',
    body: '<InstanceID>0</InstanceID><Speed>1</Speed>',
  );

  Future<void> pause(SonosDevice device) => _soap(
    device,
    service: _avTransport,
    endpoint: '/MediaRenderer/AVTransport/Control',
    action: 'Pause',
    body: '<InstanceID>0</InstanceID>',
  );

  Future<void> stop(SonosDevice device) => _soap(
    device,
    service: _avTransport,
    endpoint: '/MediaRenderer/AVTransport/Control',
    action: 'Stop',
    body: '<InstanceID>0</InstanceID>',
  );

  // ── Control: volume ────────────────────────────────────────────────────────

  /// Sets speaker volume. [volume] is 0–100; values outside are clamped.
  Future<void> setVolume(SonosDevice device, int volume) {
    final v = volume.clamp(0, 100);
    return _soap(
      device,
      service: _renderingControl,
      endpoint: '/MediaRenderer/RenderingControl/Control',
      action: 'SetVolume',
      body:
          '<InstanceID>0</InstanceID>'
          '<Channel>Master</Channel>'
          '<DesiredVolume>$v</DesiredVolume>',
    );
  }

  /// Reads current speaker volume (0–100), or null if it can't be read.
  Future<int?> getVolume(SonosDevice device) async {
    final resp = await _soap(
      device,
      service: _renderingControl,
      endpoint: '/MediaRenderer/RenderingControl/Control',
      action: 'GetVolume',
      body: '<InstanceID>0</InstanceID><Channel>Master</Channel>',
    );
    final raw = _tagValue(resp, 'CurrentVolume');
    return raw == null ? null : int.tryParse(raw);
  }

  // ── Control: state ─────────────────────────────────────────────────────────

  /// Reads the speaker's current transport state (playing/paused/...).
  Future<SonosPlaybackState> getPlaybackState(SonosDevice device) async {
    try {
      final resp = await _soap(
        device,
        service: _avTransport,
        endpoint: '/MediaRenderer/AVTransport/Control',
        action: 'GetTransportInfo',
        body: '<InstanceID>0</InstanceID>',
      );
      switch (_tagValue(resp, 'CurrentTransportState')) {
        case 'PLAYING':
          return SonosPlaybackState.playing;
        case 'PAUSED_PLAYBACK':
          return SonosPlaybackState.paused;
        case 'STOPPED':
          return SonosPlaybackState.stopped;
        case 'TRANSITIONING':
          return SonosPlaybackState.transitioning;
        default:
          return SonosPlaybackState.unknown;
      }
    } catch (_) {
      return SonosPlaybackState.unknown;
    }
  }

  // ── SOAP plumbing ──────────────────────────────────────────────────────────

  /// Performs one SOAP action against a speaker and returns the raw
  /// response body. Throws a human-readable [Exception] on network
  /// failure, timeout, or a UPnP fault, so UI callers can surface it.
  Future<String> _soap(
    SonosDevice device, {
    required String service,
    required String endpoint,
    required String action,
    required String body,
  }) async {
    final client = clientFactory();
    try {
      final envelope =
          '<?xml version="1.0" encoding="utf-8"?>'
          '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
          's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
          '<s:Body>'
          '<u:$action xmlns:u="$service">$body</u:$action>'
          '</s:Body></s:Envelope>';

      final resp = await client
          .post(
            Uri.parse('http://${device.ip}:$_controlPort$endpoint'),
            headers: {
              'Content-Type': 'text/xml; charset="utf-8"',
              'SOAPACTION': '"$service#$action"',
            },
            body: envelope,
          )
          .timeout(_controlTimeout);

      if (resp.statusCode == 200) return resp.body;

      // Sonos returns HTTP 500 with a UPnP <errorCode> on faults.
      final code = _tagValue(resp.body, 'errorCode');
      throw Exception(
        code != null
            ? 'De speaker weigerde de opdracht (fout $code).'
            : 'De speaker reageerde onverwacht (${resp.statusCode}).',
      );
    } on TimeoutException {
      throw Exception('De Sonos-speaker reageert niet. Staat hij nog aan?');
    } on SocketException {
      throw Exception('Kan de Sonos-speaker niet bereiken op het netwerk.');
    } finally {
      client.close();
    }
  }

  // ── Small helpers ──────────────────────────────────────────────────────────

  /// Builds the Sonos radio-stream URI form from a plain http(s) URL.
  static String _toRadioUri(String streamUrl) {
    final withoutScheme = streamUrl.replaceFirst(RegExp(r'^https?://'), '');
    return 'x-rincon-mp3radio://$withoutScheme';
  }

  /// Minimal DIDL-Lite metadata so the speaker shows a sensible title.
  static String _radioMetadata(String title) {
    return '<DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" '
        'xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">'
        '<item id="R:0/0/0" parentID="R:0/0" restricted="true">'
        '<dc:title>${_escape(title)}</dc:title>'
        '<upnp:class>object.item.audioItem.audioBroadcast</upnp:class>'
        '</item></DIDL-Lite>';
  }

  /// Reads a single HTTP header value out of a raw SSDP response.
  static String? _headerValue(String raw, String name) {
    for (final line in raw.split('\r\n')) {
      final idx = line.indexOf(':');
      if (idx <= 0) continue;
      if (line.substring(0, idx).trim().toUpperCase() == name.toUpperCase()) {
        return line.substring(idx + 1).trim();
      }
    }
    return null;
  }

  /// Extracts the text content of the first `<tag>...</tag>` in [xml].
  /// Deliberately tiny — the responses we parse have flat, predictable
  /// shapes, so this avoids promoting `xml` to a direct dependency.
  static String? _tagValue(String xml, String tag) {
    final match = RegExp(
      '<$tag[^>]*>(.*?)</$tag>',
      dotAll: true,
    ).firstMatch(xml);
    return match?.group(1)?.trim();
  }

  /// XML-escapes a value for safe embedding inside a SOAP body. Note
  /// nested metadata is escaped twice on purpose (Sonos expects the
  /// DIDL-Lite to arrive as an escaped string inside the envelope).
  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  void dispose() {
    _devicesController.close();
  }
}
