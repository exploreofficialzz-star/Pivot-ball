import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// NetworkMonitor — watches connectivity for the entire app lifetime.
///
/// Call [initialize] once in main(). Then read [isOnline] anywhere.
/// MaterialApp.builder in main.dart shows an overlay when the device is offline.
class NetworkMonitor {
  static final NetworkMonitor _instance = NetworkMonitor._();
  static NetworkMonitor get instance => _instance;
  NetworkMonitor._();

  final ValueNotifier<bool> isOnline = ValueNotifier(true);
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Initial check
    try {
      final result = await Connectivity().checkConnectivity()
          .timeout(const Duration(seconds: 4));
      isOnline.value = result.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      isOnline.value = false;
    }

    // Continuous monitoring — fires on every network change
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (isOnline.value != online) {
        isOnline.value = online;
      }
    });
  }

  void dispose() {
    _sub?.cancel();
    isOnline.dispose();
  }
}
