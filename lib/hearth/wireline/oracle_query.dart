import 'dart:convert';

import '../harbor/path_verdict.dart';
import '../lore/frost_config.dart';
import 'courier_hawk.dart';
import 'ember_vault.dart';

// ============================================================
// ORACLE QUERY — POST the assembled body, cache the answer.
// ============================================================
// The backend is the single source of truth for routing. On an
// approved response we cache both the URL AND its expiry so a
// returning launch can skip the network call while the URL is
// still fresh. On any failure — HTTP error, timeout, malformed
// JSON — we return a dismissed answer; the orchestrator turns
// that into a game landing (or an offline landing if reachability
// is gone).
// ============================================================

class OracleQuery {
  OracleQuery(this._vault);

  final EmberVault _vault;

  Future<OracleAnswer> ask(Map<String, dynamic> body) async {
    final String endpoint = FrostConfig.endpointUrl;
    if (endpoint.isEmpty) {
      return OracleAnswer.dismissed('endpoint_absent');
    }

    try {
      final dynamic response = await courierHawk
          .post(
            Uri.parse(endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(Duration(seconds: FrostConfig.verdictTimeoutSeconds));

      if (response.statusCode != 200) {
        return OracleAnswer.dismissed('http_${response.statusCode}');
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return OracleAnswer.dismissed('shape_mismatch');
      }
      final OracleAnswer answer = OracleAnswer.fromJson(
        Map<String, dynamic>.from(decoded),
      );

      if (answer.hasGateway) {
        await _vault.cacheGateway(answer.url!, answer.expiresAt);
      }
      return answer;
    } catch (e) {
      return OracleAnswer.dismissed('network:$e');
    }
  }
}
