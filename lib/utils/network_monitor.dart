import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Three network states checked in order:
///   offline     — no network interface (WiFi/mobile off)
///   noInternet  — interface exists but HTTP fails (weak data, no plan, captive portal)
///   online      — full HTTP confirmed
enum NetworkStatus { online, noInternet, offline }

class NetworkMonitor {
  static final NetworkMonitor _instance = NetworkMonitor._();
  static NetworkMonitor get instance => _instance;
  NetworkMonitor._();

  final ValueNotifier<NetworkStatus> status = ValueNotifier(NetworkStatus.online);
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _pingTimer;
  bool _initialized = false;

  bool get isOnline => status.value == NetworkStatus.online;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _refresh();

    // React immediately on interface changes
    _sub = Connectivity().onConnectivityChanged.listen((_) => _refresh());

    // Re-verify every 20s — catches weak data degrading mid-session
    _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) => _refresh());
  }

  Future<void> _refresh() async {
    // Step 1 — does the device have any network interface?
    final conn = await Connectivity().checkConnectivity()
        .timeout(const Duration(seconds: 4),
            onTimeout: () => [ConnectivityResult.none]);

    final hasInterface = conn.any((r) => r != ConnectivityResult.none);
    if (!hasInterface) {
      status.value = NetworkStatus.offline;
      return;
    }

    // Step 2 — can the device actually send/receive data?
    // Use Google's lightweight generate_204 endpoint (zero-byte body, fast).
    final hasData = await _hasRealData();
    status.value = hasData ? NetworkStatus.online : NetworkStatus.noInternet;
  }

  /// Verifies real data flow with an HTTP request.
  /// DNS-only checks pass even on captive portals or expired data plans.
  Future<bool> _hasRealData() async {
    try {
      final client   = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request  = await client
          .getUrl(Uri.parse('https://connectivitycheck.gstatic.com/generate_204'))
          .timeout(const Duration(seconds: 6));
      final response = await request.close()
          .timeout(const Duration(seconds: 6));
      client.close();
      // 204 = Google confirms connectivity; any 2xx is fine
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      // Fallback: try plain DNS if HTTP fails (some firewalls block HTTP but not DNS)
      try {
        final dns = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 4));
        return dns.isNotEmpty && dns[0].rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    }
  }

  void dispose() {
    _sub?.cancel();
    _pingTimer?.cancel();
    status.dispose();
  }
}
