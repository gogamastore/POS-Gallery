import 'dart:convert';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:myapp/models/product.dart';

class AiStockService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<Product>> fetchProducts() async {
    final snapshot = await _db.collection('products').get();
    return snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();
  }

  Future<List<Map<String, dynamic>>> getSalesDataForProduct(
      String productId, DateTime startDate, DateTime endDate) async {
    final List<Map<String, dynamic>> salesData = [];

    final ordersQuery = _db
        .collection('orders')
        .where('productIds', arrayContains: productId)
        .where('status', whereIn: [
          'Processing',
          'processing',
          'Shipped',
          'shipped',
          'Delivered',
          'delivered'
        ])
        .where('validatedAt', isGreaterThanOrEqualTo: startDate)
        .where('validatedAt', isLessThanOrEqualTo: endDate);

    final querySnapshot = await ordersQuery.get();
    for (var doc in querySnapshot.docs) {
      final order = doc.data();
      final validationDate = order['validatedAt'] != null
          ? (order['validatedAt'] as Timestamp).toDate()
          : (order['date'] as Timestamp).toDate();

      for (var item in order['products']) {
        if (item['productId'] == productId) {
          salesData.add({
            'orderDate': validationDate.toIso8601String(),
            'quantity': item['quantity'],
          });
        }
      }
    }

    return salesData;
  }

  // --- FUNGSI PARSING TIGA LAPIS ---
  Map<String, dynamic> _parseJsonResponse(String rawText) {
    // Lapis 1: Regex untuk ekstraksi kasar blok JSON.
    final RegExp jsonRegExp = RegExp(r'\{.*\}', dotAll: true);
    final Match? match = jsonRegExp.firstMatch(rawText);

    if (match == null) {
      throw const FormatException('Tidak ditemukan blok JSON yang valid (menggunakan Regex).');
    }

    String jsonString = match.group(0)!;

    // Lapis 2: Coba decode langsung. Ini berhasil untuk JSON yang bersih.
    try {
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      developer.log('Gagal decode langsung, mencoba pembersihan lanjutan...', name: 'JSON_PARSER');
      // Lanjut ke lapis 3 jika gagal
    }

    // Lapis 3: Pembersihan karakter kontrol tak terlihat dan coba lagi.
    // Ini menangani kasus adanya karakter seperti BOM (Byte Order Mark).
    try {
      // Hapus semua karakter non-printable kecuali whitespace standar.
      jsonString = jsonString.replaceAll(RegExp(r'[^\x20-\x7E\n\r\t]'), '');
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Gagal mem-parsing JSON bahkan setelah pembersihan lanjutan: $e');
    }
  }

  Future<Map<String, dynamic>> getStockSuggestion(
      {
      required String productName,
      required int currentStock,
      required List<Map<String, dynamic>> salesData,
      required String analysisPeriod}) async {

    final generationConfig = GenerationConfig(
      responseMimeType: 'application/json',
    );
        
    final model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.5-flash',
      generationConfig: generationConfig,
    );

    final prompt = '''
    Sebagai seorang analis rantai pasokan ahli, tugas Anda adalah memberikan rekomendasi stok yang mendalam untuk sebuah produk.

    DATA YANG DIBERIKAN:
    - Nama Produk: $productName
    - Stok Saat Ini: $currentStock unit
    - Periode Analisis: $analysisPeriod
    - Data Penjualan Historis (format JSON): ${jsonEncode(salesData)}

    TUGAS ANDA:
    1. ANALISIS DATA PENJUALAN: Identifikasi tren penjualan (misalnya, 'Stabil', 'Meningkat', 'Menurun'), total unit terjual, dan periode puncak penjualan (hari atau tanggal dengan penjualan tertinggi).
    2. HITUNG REKOMENDASI: Berdasarkan analisis, tentukan dua angka penting:
        a. `nextPeriodStock`: Jumlah stok ideal untuk periode 30 hari ke depan.
        b. `safetyStock`: Stok pengaman untuk mengantisipasi lonjakan permintaan atau keterlambatan.
    3. BERIKAN ALASAN YANG JELAS: Tulis `reasoning` (alasan) yang logis dan berbasis data untuk setiap angka rekomendasi Anda. Jelaskan bagaimana Anda sampai pada angka tersebut.

    FORMAT OUTPUT (WAJIB DIPATUHI):
    Respons Anda HARUS berupa string JSON tunggal yang valid, dimulai dengan '{' dan diakhiri dengan '}'. Jangan sertakan teks atau markdown lain di luar objek JSON.

    Struktur JSON yang Diperlukan:
    {
      "suggestion": {
        "nextPeriodStock": <number>,
        "safetyStock": <number>
      },
      "analysis": {
        "totalSold": <number>,
        "salesTrend": "<string>",
        "peakDays": ["<string>", "<string>"]
      },
      "reasoning": "<string>"
    }
    ''';

    final content = [Content.text(prompt)];
    final response = await model.generateContent(content);

    if (response.text != null) {
      final rawText = response.text!;
      developer.log('--- RESPONS MENTAH DARI AI ---\n$rawText\n--- AKHIR RESPONS ---', name: 'AI_RESPONSE');

      try {
        // Panggil fungsi parsing tiga lapis yang baru
        return _parseJsonResponse(rawText);
      } catch(e) {
         throw Exception('Gagal mem-parsing hasil AI: $e\nRespons mentah: ${response.text}');
      }
    } else {
      throw Exception('Gagal mendapatkan saran dari AI (respons null).');
    }
  }
}
