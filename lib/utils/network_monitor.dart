import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Two-level network state:
///   [NetworkStatus.online]      — connected AND real internet confirmed
///   [NetworkStatus.noInternet]  — connected (WiFi/data) but no real internet
///                                 (e.g. WiFi with no data plan, captive portal)
///   [NetworkStatus.offline]     — no network interface at all
enum NetworkStatus { online, noInternet, offline }

class NetworkMonitor {
  static final NetworkMonitor _instance = NetworkMonitor._();
  static NetworkMonitor get instance => _instance;
  NetworkMonitor._();

  final ValueNotifier<NetworkStatus> status =
      ValueNotifier(NetworkStatus.online);

  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _pingTimer;
  bool _initialized = false;

  bool get isOnline => status.value == NetworkStatus.online;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // First check
    await _refresh();

    // React to interface changes immediately
    _sub = Connectivity().onConnectivityChanged.listen((_) => _refresh());

    // Re-verify real internet every 30s (catches data plan expiry mid-session)
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  Future<void> _refresh() async {
    final conn = await Connectivity().checkConnectivity()
        .timeout(const Duration(seconds: 4), onTimeout: () => [ConnectivityResult.none]);

    final hasInterface = conn.any((r) => r != ConnectivityResult.none);

    if (!hasInterface) {
      status.value = NetworkStatus.offline;
      return;
    }

    // Interface exists — now verify real internet with DNS lookup
    final hasReal = await _hasRealInternet();
    status.value = hasReal ? NetworkStatus.online : NetworkStatus.noInternet;
  }

  Future<bool> _hasRealInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _sub?.cancel();
    _pingTimer?.cancel();
    status.dispose();
  }
}
