import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Wrapper untuk Cloud Function Midtrans (region asia-southeast1) — fungsi
/// yang sama dengan aplikasi marketplace pembeli.
///
/// Untuk pesanan `source: 'pos'`, server memeriksa role kasir/admin. Begitu
/// pembeli membayar, webhook `handleMidtransNotification` menuntaskan pesanan
/// di server (status 'success', paymentStatus 'paid', potong stok).
class MidtransService {
  static const _region = 'asia-southeast1';

  /// Membuat transaksi Snap untuk pesanan dan mengembalikan URL halaman
  /// pembayarannya. Melempar [MidtransException] bila gagal — penelepon
  /// cukup menampilkan pesannya.
  Future<String> createSnapTransaction(String orderId) async {
    final data =
        await _call('createMidtransTransaction', {'orderId': orderId});
    return data['redirectUrl'] as String;
  }

  Future<Map<String, dynamic>> _call(
      String name, Map<String, dynamic> payload) async {
    // Plugin cloud_functions belum punya implementasi Windows → di sana
    // endpoint callable dipanggil langsung lewat HTTPS.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return _callOverHttp(name, payload);
    }
    try {
      final callable = FirebaseFunctions.instanceFor(region: _region)
          .httpsCallable(name);
      final result = await callable.call(payload);
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw MidtransException(e.message ?? e.code);
    }
  }

  /// Protokol callable Firebase: POST `{"data": ...}` dengan ID token,
  /// balasan `{"result": ...}` atau `{"error": {"status", "message"}}`.
  Future<Map<String, dynamic>> _callOverHttp(
      String name, Map<String, dynamic> payload) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const MidtransException('Silakan login terlebih dahulu.');
    }
    final idToken = await user.getIdToken();
    final projectId = Firebase.app().options.projectId;

    final response = await http.post(
      Uri.parse('https://$_region-$projectId.cloudfunctions.net/$name'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'data': payload}),
    );

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      body = const {};
    }

    final error = body['error'];
    if (response.statusCode != 200 || error != null) {
      throw MidtransException(error is Map && error['message'] is String
          ? error['message'] as String
          : 'Gagal memanggil $name (HTTP ${response.statusCode}).');
    }
    return Map<String, dynamic>.from(body['result'] as Map);
  }
}

class MidtransException implements Exception {
  final String message;

  const MidtransException(this.message);

  @override
  String toString() => message;
}
