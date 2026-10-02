import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../services/admin_chat_service.dart';

/// Percakapan admin ↔ satu pembeli (thread chats/{userId}).
class AdminChatScreen extends StatefulWidget {
  final String userId;
  final String title;
  const AdminChatScreen({super.key, required this.userId, required this.title});

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  final _service = AdminChatService();
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();

  File? _imageFile;
  bool _sending = false;
  late String _title;

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _service.markRead(widget.userId);
    // Kartu nama chat = nama profil pembeli (user/{uid}.name), bukan userId.
    _service.ensureThreadProfile(widget.userId).then((name) {
      if (name.isNotEmpty && mounted) setState(() => _title = name);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _controller.text;
    if (text.trim().isEmpty && _imageFile == null) return;

    setState(() => _sending = true);
    try {
      String? imageUrl;
      if (_imageFile != null) {
        imageUrl = await _service.uploadImage(widget.userId, _imageFile!);
      }
      await _service.sendMessage(
          userId: widget.userId, text: text, imageUrl: imageUrl);
      _controller.clear();
      setState(() => _imageFile = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal mengirim pesan: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_title, overflow: TextOverflow.ellipsis)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _service.messagesStream(widget.userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data ?? [];

                // Tandai dibaca bila pesan terakhir dari pembeli.
                if (messages.isNotEmpty && messages.last.senderRole == 'user') {
                  _service.markRead(widget.userId);
                }

                if (messages.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Belum ada pesan.\nMulai balas pembeli di sini.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) {
                    _scroll.jumpTo(_scroll.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) => _bubble(theme, messages[i]),
                );
              },
            ),
          ),
          _inputBar(theme),
        ],
      ),
    );
  }

  Widget _bubble(ThemeData theme, ChatMessage m) {
    final mine = m.isAdmin; // pesan admin di kanan
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: mine ? theme.colorScheme.primary : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 2),
            bottomRight: Radius.circular(mine ? 2 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.imageUrl != null)
              Padding(
                padding: EdgeInsets.only(bottom: m.text.isNotEmpty ? 6 : 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: m.imageUrl!,
                    width: 200,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(
                      width: 200,
                      height: 150,
                      color: Colors.black12,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (c, u, e) =>
                        const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            if (m.text.isNotEmpty)
              Text(m.text,
                  style: TextStyle(color: mine ? Colors.white : Colors.black87)),
            if (m.createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  DateFormat('HH:mm').format(m.createdAt!.toDate()),
                  style: TextStyle(
                      fontSize: 10,
                      color: mine ? Colors.white70 : Colors.black45),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _inputBar(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.cardColor,
          border: Border(top: BorderSide(color: Colors.grey[300]!)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_imageFile != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(_imageFile!,
                            width: 72, height: 72, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: GestureDetector(
                          onTap: () => setState(() => _imageFile = null),
                          child: const CircleAvatar(
                            radius: 11,
                            backgroundColor: Colors.red,
                            child: Icon(Icons.close,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image_outlined),
                  onPressed: _sending ? null : _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'Ketik balasan...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _sending
                    ? const SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : IconButton.filled(
                        icon: const Icon(Icons.send),
                        onPressed: _send,
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
