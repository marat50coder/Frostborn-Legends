import 'package:http/http.dart' as http;

import 'frost_mask.dart';

// ============================================================
// COURIER HAWK — HTTP client that always wears the frost mask.
// ============================================================
// Every outbound request in the hearth flow (verdict POST, GCD
// rescue, push image fetch) is routed through this client. The
// User-Agent is stamped unconditionally so nothing ever leaks the
// default `dart-io/x.y` shape.
// ============================================================

class CourierHawk extends http.BaseClient {
  CourierHawk() : _delegate = http.Client();

  final http.Client _delegate;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['User-Agent'] = FrostMask.userAgent;
    return _delegate.send(request);
  }

  @override
  void close() => _delegate.close();
}

/// Shared client instance — one per process. Only usable AFTER
/// [FrostMask.prime] has completed inside main().
final CourierHawk courierHawk = CourierHawk();
