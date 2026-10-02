import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/admin_chat_service.dart';
import 'admin_chat_screen.dart';

/// Kotak masuk chat: daftar semua percakapan pembeli (sisi admin).
class AdminChatListScreen extends StatelessWidget {
  const AdminChatListScreen({super.key});

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final sameDay =
        now.year == dt.year && now.month == dt.month && now.day == dt.day;
    return sameDay
        ? DateFormat('HH:mm').format(dt)
        : DateFormat('dd/MM/yy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final service = AdminChatService();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Chat Pembeli'), centerTitle: true),
      body: StreamBuilder<List<ChatThread>>(
        stream: service.threadsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Gagal memuat percakapan: ${snapshot.error}'));
          }
          final threads = snapshot.data ?? [];
          if (threads.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('Belum ada percakapan dari pembeli.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: threads.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final t = threads[i];
              final unread = t.unreadForAdmin > 0;
              return ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: t.userPhotoURL.isNotEmpty
                      ? CachedNetworkImageProvider(t.userPhotoURL)
                      : null,
                  child: t.userPhotoURL.isEmpty
                      ? Text(
                          t.title.isNotEmpty ? t.title[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                title: Text(
                  t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: unread ? FontWeight.bold : FontWeight.w500),
                ),
                subtitle: Text(
                  (t.lastSenderRole == 'admin' ? 'Anda: ' : '') + t.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: unread ? Colors.black87 : Colors.grey.shade600,
                    fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (t.lastMessageAt != null)
                      Text(
                        _formatTime(t.lastMessageAt!.toDate()),
                        style: TextStyle(
                            fontSize: 11,
                            color: unread
                                ? theme.colorScheme.primary
                                : Colors.grey),
                      ),
                    const SizedBox(height: 4),
                    if (unread)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          t.unreadForAdmin > 99 ? '99+' : '${t.unreadForAdmin}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AdminChatScreen(userId: t.userId, title: t.title),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
