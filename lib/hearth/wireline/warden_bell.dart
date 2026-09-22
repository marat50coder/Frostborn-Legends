import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'courier_hawk.dart';
import 'ember_vault.dart';

// ============================================================
// WARDEN BELL — Firebase Messaging + local notifications.
// ============================================================
// [boot] must finish BEFORE the orchestrator reads the pending
// URL. boot awaits getInitialMessage (and any local-launch
// payload) and only then writes the vault slot. Invert that
// order and a killed-app tap opens the cached homepage.
//
// Partners put the destination under many keys (`url`, `link`,
// `deep_link`, …) and sometimes nest it. Reading only
// `data['url']` drops most production payloads.
//
// A warm tap that lands before GreatGateScene hooks the sink is
// queued in memory and also parked in the vault, so Kindling
// cannot swallow it. Data-only FCM messages are rendered here
// with a unique id — the OS only auto-draws a tray item when a
// `notification` block is present, which is why a second campaign
// used to vanish.
//
// Channel id must match `default_notification_channel_id` in
// AndroidManifest.xml.
// ============================================================

const String bellChannelId = 'frost_bulletin_v1';
const String bellChannelName = 'Frostborn Updates';

// flutter_local_notifications wants a raw resource NAME, never
// `@drawable/...` — that form silently drops every local banner.
const String _smallIconRes = 'ic_bell_flame';
const String _largeIconRes = 'ic_launcher';

const List<String> _hrefKeys = <String>[
  'url',
  'link',
  'deep_link',
  'deeplink',
  'target',
  'landing',
  'click_url',
  'open_url',
  'href',
  'redirect',
  'action',
  'click_action',
  'af_dp',
  'af_web_dp',
  'deep_link_value',
  'destination',
  'page',
  'go',
];

const List<String> _nestedBags = <String>[
  'payload',
  'data',
  'aps',
  'custom',
];

const List<String> _titleKeys = <String>[
  'title',
  'alert',
  'subject',
];

const List<String> _bodyKeys = <String>[
  'body',
  'message',
  'text',
  'content',
  'descr',
];

/// Background isolate. Data-only packets are drawn here; a
/// `notification` block is already rendered by the OS.
@pragma('vm:entry-point')
Future<void> hearthBellIsolate(RemoteMessage message) async {
  if (message.notification != null) return;
  try {
    WidgetsFlutterBinding.ensureInitialized();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    final FlutterLocalNotificationsPlugin local =
        FlutterLocalNotificationsPlugin();
    await local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_smallIconRes),
      ),
    );
    if (Platform.isAndroid) {
      await local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
        const AndroidNotificationChannel(
          bellChannelId,
          bellChannelName,
          description: 'Bonuses, promos and game updates',
          importance: Importance.high,
        ),
      );
    }
    await _presentBanner(local, message);
  } catch (_) {}
}

class WardenBell {
  WardenBell(this._vault);

  final EmberVault _vault;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _messaging;
  String? _token;
  bool _ready = false;

  final Queue<String> _heldHrefs = Queue<String>();
  void Function(String url)? _sink;

  /// Warm-tap delivery. Assigning a sink drains any href that
  /// arrived while Kindling / the invite was still on screen.
  void Function(String url)? get onWarmUrl => _sink;
  set onWarmUrl(void Function(String url)? cb) {
    _sink = cb;
    if (cb == null) return;
    while (_heldHrefs.isNotEmpty) {
      cb(_heldHrefs.removeFirst());
    }
  }

  /// Global fallback — fires when a warm tap arrives while no
  /// GreatGateScene sink is attached (Kindling, invite scene, or
  /// the slot game is on top). The wiring in main.dart uses this
  /// to push a fresh WebView route via the app-level navigator,
  /// so a tap from the game never becomes a silent no-op.
  void Function(String url)? onGlobalWarmUrl;

  /// FCM rotated the token. The orchestrator re-POSTs the verdict
  /// so the backend can target this device.
  void Function(String token)? onTokenChanged;

  String? get token => _token;

  /// Full arming. Await this BEFORE [SnowdriftLatch.release].
  Future<void> boot() async {
    if (_ready) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(hearthBellIsolate);

      await _setupLocal();

      final RemoteMessage? initial = await _messaging!
          .getInitialMessage()
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      if (initial != null) {
        await _ingestColdTap(initial);
      }

      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onWarmTap);
      _messaging!.onTokenRefresh.listen((String t) {
        _token = t;
        onTokenChanged?.call(t);
      });

      _token = await _messaging!
          .getToken()
          .timeout(const Duration(seconds: 8), onTimeout: () => _token);

      _ready = true;
    } catch (_) {
      // Firebase not configured yet — bell stays dormant.
    }
  }

  Future<void> _setupLocal() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings(_smallIconRes);
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        final String? href = _hrefFromPayload(r.payload);
        if (href != null) _handOffWarm(href);
      },
    );

    final NotificationAppLaunchDetails? launch =
        await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      final String? href =
          _hrefFromPayload(launch!.notificationResponse?.payload);
      if (href != null) await _vault.stashPending(href);
    }

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _local.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          bellChannelId,
          bellChannelName,
          description: 'Bonuses, promos and game updates',
          importance: Importance.high,
        ),
      );
    }
  }

  /// System permission prompt. Records the hard-denial flag so the
  /// invite stops reappearing after a "no".
  Future<bool> askForBell() async {
    if (_messaging == null) return false;
    final NotificationSettings settings =
        await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final AuthorizationStatus status = settings.authorizationStatus;
    final bool granted = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
    await _vault.markBellGranted(granted);
    if (status == AuthorizationStatus.denied) {
      await _vault.markBellHardDenied();
    }
    return granted;
  }

  void _onForeground(RemoteMessage message) async {
    if (!Platform.isAndroid) return;
    // Foreground: the OS never draws the tray item. Render both
    // notification-block and data-only packets so campaign #2+
    // actually appear.
    await _presentBanner(_local, message);
  }

  Future<void> _ingestColdTap(RemoteMessage message) async {
    final String? href = pluckHref(message.data);
    if (href == null || href.isEmpty) return;
    await _vault.stashPending(href);
  }

  void _onWarmTap(RemoteMessage message) {
    final String? href = pluckHref(message.data);
    if (href == null || href.isEmpty) return;
    _handOffWarm(href);
  }

  void _handOffWarm(String href) {
    // Park the URL first — every branch below can then rely on it
    // surviving a race (Kindling completing between two callbacks,
    // the app being killed by the OS, etc.).
    _vault.stashPending(href);

    final void Function(String url)? cb = _sink;
    if (cb != null) {
      cb(href);
      return;
    }

    final void Function(String url)? global = onGlobalWarmUrl;
    if (global != null) {
      global(href);
      return;
    }

    _heldHrefs.add(href);
  }

  String? _hrefFromPayload(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object decoded = jsonDecode(raw);
      if (decoded is Map) {
        return pluckHref(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return pluckHref(<String, dynamic>{'url': raw});
  }
}

/// First non-empty http(s) destination in [data].
String? pluckHref(Map<String, dynamic> data) {
  for (final String key in _hrefKeys) {
    final String? value = _asText(data[key]);
    if (value != null && _isPageHref(value)) return value;
    if (value != null && value.isNotEmpty && !_looksLikeImage(value)) {
      // Some partners send a scheme-less host; still accept a
      // clear http(s) string that failed _isPageHref only because
      // of whitespace we already trimmed in _asText.
      if (value.startsWith('http://') || value.startsWith('https://')) {
        return value;
      }
    }
  }
  for (final String bag in _nestedBags) {
    final Object? nested = data[bag];
    if (nested is Map) {
      final String? found = pluckHref(Map<String, dynamic>.from(nested));
      if (found != null) return found;
    } else if (nested is String && nested.trim().isNotEmpty) {
      try {
        final Object decoded = jsonDecode(nested);
        if (decoded is Map) {
          final String? found =
              pluckHref(Map<String, dynamic>.from(decoded));
          if (found != null) return found;
        }
      } catch (_) {}
    }
  }
  for (final Object? value in data.values) {
    final String? text = _asText(value);
    if (text != null && _isPageHref(text)) return text;
  }
  return null;
}

String? _asText(Object? value) {
  if (value is String) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return null;
}

bool _isPageHref(String value) {
  if (!value.startsWith('http://') && !value.startsWith('https://')) {
    return false;
  }
  return !_looksLikeImage(value);
}

bool _looksLikeImage(String value) {
  final String lower = value.toLowerCase();
  return lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.svg') ||
      lower.endsWith('.ico') ||
      lower.endsWith('.bmp');
}

int _bannerId(RemoteMessage message) {
  final String raw = message.messageId ??
      '${message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().microsecondsSinceEpoch}';
  return raw.hashCode & 0x7fffffff;
}

String _bannerTitle(RemoteMessage message) {
  final String? fromBlock = message.notification?.title?.trim();
  if (fromBlock != null && fromBlock.isNotEmpty) return fromBlock;
  for (final String key in _titleKeys) {
    final String? text = _asText(message.data[key]);
    if (text != null) return text;
  }
  return bellChannelName;
}

String _bannerBody(RemoteMessage message) {
  final String? fromBlock = message.notification?.body?.trim();
  if (fromBlock != null && fromBlock.isNotEmpty) return fromBlock;
  for (final String key in _bodyKeys) {
    final String? text = _asText(message.data[key]);
    if (text != null) return text;
  }
  return '';
}

Future<void> _presentBanner(
  FlutterLocalNotificationsPlugin local,
  RemoteMessage message,
) async {
  AndroidNotificationDetails? details;
  final String? imageUrl = message.notification?.android?.imageUrl ??
      _asText(message.data['image']) ??
      _asText(message.data['image_url']) ??
      _asText(message.data['imageUrl']);
  if (imageUrl != null && imageUrl.isNotEmpty) {
    final Uint8List? bytes = await _fetchImage(imageUrl);
    if (bytes != null) {
      details = AndroidNotificationDetails(
        bellChannelId,
        bellChannelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: _smallIconRes,
        tag: message.messageId,
        styleInformation: BigPictureStyleInformation(
          ByteArrayAndroidBitmap(bytes),
          largeIcon: const DrawableResourceAndroidBitmap(_largeIconRes),
        ),
      );
    }
  }

  details ??= AndroidNotificationDetails(
    bellChannelId,
    bellChannelName,
    importance: Importance.high,
    priority: Priority.high,
    icon: _smallIconRes,
    tag: message.messageId,
  );

  await local.show(
    id: _bannerId(message),
    title: _bannerTitle(message),
    body: _bannerBody(message),
    notificationDetails: NotificationDetails(android: details),
    payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
  );
}

Future<Uint8List?> _fetchImage(String url) async {
  try {
    final dynamic res = await courierHawk
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) return res.bodyBytes as Uint8List;
  } catch (_) {}
  return null;
}
