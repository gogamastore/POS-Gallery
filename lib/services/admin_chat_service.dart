import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Satu thread per pembeli: chats/{userId}. Sisi ADMIN (POS-Gallery).
class ChatThread {
  final String userId;
  final String userName;
  final String userEmail;
  final String userPhotoURL;
  final String lastMessage;
  final Timestamp? lastMessageAt;
  final String lastSenderRole;
  final int unreadForAdmin;

  ChatThread({
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userPhotoURL,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastSenderRole,
    required this.unreadForAdmin,
  });

  factory ChatThread.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ChatThread(
      userId: doc.id,
      userName: (d['userName'] ?? '').toString(),
      userEmail: (d['userEmail'] ?? '').toString(),
      userPhotoURL: (d['userPhotoURL'] ?? '').toString(),
      lastMessage: (d['lastMessage'] ?? '').toString(),
      lastMessageAt: d['lastMessageAt'] as Timestamp?,
      lastSenderRole: (d['lastSenderRole'] ?? '').toString(),
      unreadForAdmin: (d['unreadForAdmin'] as num? ?? 0).toInt(),
    );
  }

  String get title => userName.isNotEmpty
      ? userName
      : (userEmail.isNotEmpty ? userEmail : userId);
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderRole; // 'user' | 'admin'
  final String text;
  final String? imageUrl;
  final Timestamp? createdAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.text,
    required this.imageUrl,
    required this.createdAt,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return ChatMessage(
      id: doc.id,
      senderId: (d['senderId'] ?? '').toString(),
      senderRole: (d['senderRole'] ?? '').toString(),
      text: (d['text'] ?? '').toString(),
      imageUrl: d['imageUrl'] as String?,
      createdAt: d['createdAt'] as Timestamp?,
    );
  }

  bool get isAdmin => senderRole == 'admin';
}

/// Profil pembeli dari koleksi `user/{uid}` (bukan dari customerDetails pesanan).
class BuyerProfile {
  final String name;
  final String email;
  final String photoURL;
  final String whatsapp;
  const BuyerProfile({
    this.name = '',
    this.email = '',
    this.photoURL = '',
    this.whatsapp = '',
  });

  String get displayName =>
      name.isNotEmpty ? name : (email.isNotEmpty ? email : '');
}

class AdminChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Ambil profil pembeli dari `user/{userId}` (nama, email, foto, whatsapp).
  Future<BuyerProfile?> fetchBuyerProfile(String userId) async {
    if (userId.isEmpty || userId == 'guest') return null;
    try {
      final doc = await _db.collection('user').doc(userId).get();
      if (!doc.exists) return null;
      final d = doc.data() ?? {};
      return BuyerProfile(
        name: (d['name'] ?? d['displayName'] ?? '').toString(),
        email: (d['email'] ?? '').toString(),
        photoURL: (d['photoURL'] ?? '').toString(),
        whatsapp: (d['whatsapp'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Pastikan dokumen thread memakai NAMA PROFIL pembeli (bukan userId) sebagai
  /// kartu nama. Dipanggil saat layar chat dibuka. Mengembalikan nama tampilan.
  Future<String> ensureThreadProfile(String userId) async {
    final p = await fetchBuyerProfile(userId);
    if (p == null) return '';
    final updates = <String, dynamic>{};
    if (p.name.isNotEmpty) updates['userName'] = p.name;
    if (p.email.isNotEmpty) updates['userEmail'] = p.email;
    if (p.photoURL.isNotEmpty) updates['userPhotoURL'] = p.photoURL;
    if (updates.isNotEmpty) {
      updates['userId'] = userId;
      await _db
          .collection('chats')
          .doc(userId)
          .set(updates, SetOptions(merge: true));
    }
    return p.displayName;
  }

  /// Semua percakapan, terbaru di atas.
  Stream<List<ChatThread>> threadsStream() {
    return _db
        .collection('chats')
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ChatThread.fromDoc(d)).toList());
  }

  Stream<List<ChatMessage>> messagesStream(String userId) {
    return _db
        .collection('chats')
        .doc(userId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ChatMessage.fromDoc(d)).toList());
  }

  Future<String> uploadImage(String userId, File file) async {
    final ref = _storage
        .ref()
        .child('chat_images')
        .child(userId)
        .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  /// Kirim pesan sebagai ADMIN ke thread pembeli tertentu.
  Future<void> sendMessage({
    required String userId,
    required String text,
    String? imageUrl,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && imageUrl == null) return;

    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    final threadRef = _db.collection('chats').doc(userId);

    await threadRef.collection('messages').add({
      'senderId': adminUid,
      'senderRole': 'admin',
      'text': trimmed,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final preview =
        trimmed.isNotEmpty ? trimmed : (imageUrl != null ? '📷 Foto' : '');

    await threadRef.set({
      'userId': userId,
      'lastMessage': preview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderRole': 'admin',
      'unreadForUser': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Tandai thread sudah dibaca admin (reset badge).
  Future<void> markRead(String userId) async {
    await _db
        .collection('chats')
        .doc(userId)
        .set({'unreadForAdmin': 0}, SetOptions(merge: true));
  }
}
