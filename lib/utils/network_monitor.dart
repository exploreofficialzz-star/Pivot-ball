import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// NetworkMonitor — watches connectivity for the entire app lifetime.
/// 
/// Usage:
///   await NetworkMonitor.instance.initialize();   // call once in main()
///   NetworkMonitor.instance.isOnline              // ValueNotifier<bool>
/// 
/// The MaterialApp.builder in main.dart reads isOnline and shows an overlay
/// whenever the device goes offline — regardless of which screen is active.
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

