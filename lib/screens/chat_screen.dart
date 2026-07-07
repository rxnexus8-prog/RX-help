import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:open_file/open_file.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../services/auth_service.dart';
import '../services/media_service.dart';
import 'call/create_room_screen.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> contact;
  const ChatScreen({super.key, required this.contact});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _supabase = Supabase.instance.client;
  final _msgCtrl = TextEditingController();
  final _scroll = ScrollController();
  final _audioPlayer = AudioPlayer();
  final _recorder = AudioRecorder();
  List<Map<String, dynamic>> _messages = [];
  bool _theirOnline = false;
  bool _isRecording = false;
  String? _recordingPath;
  String? _playingUrl;
  StreamSubscription? _msgSub;
  StreamSubscription? _onlineSub;
  Timer? _onlineTimer;

  String get _myNumber => context.read<AuthService>().currentUser!.callNumber;
  String get _myId => context.read<AuthService>().currentUser!.id;
  String get _theirNumber => widget.contact['contact_number'];
  String get _name => widget.contact['contact_name'];
  String get _masked => '${_theirNumber.substring(0, 3)}***${_theirNumber.substring(17)}';

  @override
  void initState() {
    super.initState();
    _setOnline(true);
    _loadMessages();
    _listenMessages();
    _listenOnline();
    _onlineTimer = Timer.periodic(const Duration(seconds: 30), (_) => _setOnline(true));
  }

  Future<void> _setOnline(bool online) async {
    await _supabase.from('users').update({
      'is_online': online,
      'last_seen': DateTime.now().toIso8601String(),
    }).eq('id', _myId);
  }

  void _listenOnline() {
    _onlineSub = _supabase.from('users').stream(primaryKey: ['id']).listen((data) {
      final them = data.firstWhere((u) => u['call_number'] == _theirNumber, orElse: () => {});
      if (them.isNotEmpty && mounted) setState(() => _theirOnline = them['is_online'] ?? false);
    });
  }

  Future<void> _loadMessages() async {
    final res = await _supabase.from('messages').select()
        .or('and(sender_number.eq.$_myNumber,receiver_number.eq.$_theirNumber),and(sender_number.eq.$_theirNumber,receiver_number.eq.$_myNumber)')
        .order('created_at');
    setState(() => _messages = List<Map<String, dynamic>>.from(res));
    _markRead();
    _scrollDown();
  }

  void _listenMessages() {
    _msgSub = _supabase.from('messages').stream(primaryKey: ['id']).listen((data) {
      final relevant = data.where((m) =>
        (m['sender_number'] == _myNumber && m['receiver_number'] == _theirNumber) ||
        (m['sender_number'] == _theirNumber && m['receiver_number'] == _myNumber)
      ).toList()..sort((a, b) => a['created_at'].compareTo(b['created_at']));
      setState(() => _messages = relevant);
      _markRead();
      _scrollDown();
    });
  }

  Future<void> _markRead() async {
    await _supabase.from('messages')
        .update({'is_read': true, 'is_delivered': true})
        .eq('sender_number', _theirNumber)
        .eq('receiver_number', _myNumber)
        .eq('is_read', false);
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendText() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    await _supabase.from('messages').insert({
      'sender_id': _myId,
      'sender_number': _myNumber,
      'receiver_number': _theirNumber,
      'content': text,
      'media_type': 'text',
      'is_delivered': _theirOnline,
    });
  }

  Future<void> _sendMedia(String type) async {
    Map<String, dynamic>? media;
    if (type == 'image') media = await MediaService.pickAndUploadImage();
    else if (type == 'video') media = await MediaService.pickAndUploadVideo();
    else media = await MediaService.pickAndUploadFile();
    if (media == null) return;
    await _supabase.from('messages').insert({
      'sender_id': _myId,
      'sender_number': _myNumber,
      'receiver_number': _theirNumber,
      'content': media['name'],
      'media_url': media['url'],
      'media_type': media['type'],
      'media_name': media['name'],
      'media_size': media['size'],
      'is_delivered': _theirOnline,
    });
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;
    final dir = await getTemporaryDirectory();
    _recordingPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(), path: _recordingPath!);
    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    await _recorder.stop();
    setState(() => _isRecording = false);
    if (_recordingPath == null) return;
    final file = File(_recordingPath!);
    if (!await file.exists()) return;
    final media = await MediaService.pickAndUploadFile();
    if (media == null) {
      // Upload voice directly
      final size = await file.length();
      final supabase = Supabase.instance.client;
      final path = 'audio/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await supabase.storage.from('chat-media').upload(path, file);
      final url = supabase.storage.from('chat-media').getPublicUrl(path);
      await _supabase.from('messages').insert({
        'sender_id': _myId,
        'sender_number': _myNumber,
        'receiver_number': _theirNumber,
        'content': 'Voice message',
        'media_url': url,
        'media_type': 'audio',
        'media_name': 'Voice message',
        'media_size': size,
        'is_delivered': _theirOnline,
      });
    }
  }

  Future<void> _playAudio(String url) async {
    if (_playingUrl == url) {
      await _audioPlayer.stop();
      setState(() => _playingUrl = null);
    } else {
      await _audioPlayer.play(UrlSource(url));
      setState(() => _playingUrl = url);
    }
  }

  Future<void> _deleteMessage(Map<String, dynamic> msg) async {
    if (msg['sender_number'] != _myNumber) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141420),
        title: const Text('Delete Message', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, 'me'),
            child: const Text('Delete for me', style: TextStyle(color: Colors.orange))),
          TextButton(onPressed: () => Navigator.pop(context, 'all'),
            child: const Text('Delete for everyone', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (choice == 'all') {
      await _supabase.from('messages').update({'is_deleted': true, 'content': 'This message was deleted'}).eq('id', msg['id']);
    } else if (choice == 'me') {
      await _supabase.from('messages').delete().eq('id', msg['id']);
    }
  }

  Widget _buildMessageContent(Map<String, dynamic> m, bool isMe) {
    final deleted = m['is_deleted'] == true;
    if (deleted) {
      return Text('This message was deleted',
        style: const TextStyle(color: Colors.white38, fontStyle: FontStyle.italic, fontSize: 13));
    }

    final type = m['media_type'] ?? 'text';
    final url = m['media_url'];

    if (type == 'text' || url == null) {
      return Text(m['content'] ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.white70, fontSize: 14));
    }

    if (type == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(url, width: 220, fit: BoxFit.cover,
          loadingBuilder: (_, child, prog) => prog == null ? child
              : const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
        ),
      );
    }

    if (type == 'audio') {
      final isPlaying = _playingUrl == url;
      return GestureDetector(
        onTap: () => _playAudio(url),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(isPlaying ? Icons.pause_circle : Icons.play_circle,
            color: isMe ? Colors.white : Theme.of(context).colorScheme.primary, size: 32),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Voice message', style: TextStyle(color: isMe ? Colors.white : Colors.white70, fontSize: 13)),
            Text(_formatSize(m['media_size'] ?? 0), style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
        ]),
      );
    }

    if (type == 'video') {
      return GestureDetector(
        onTap: () => OpenFile.open(url),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.videocam, color: Colors.white70, size: 28),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m['media_name'] ?? 'Video', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              Text(_formatSize(m['media_size'] ?? 0), style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
          ]),
        ),
      );
    }

    // File
    return GestureDetector(
      onTap: () => OpenFile.open(url),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.insert_drive_file, color: Colors.white70, size: 28),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m['media_name'] ?? 'File',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              overflow: TextOverflow.ellipsis),
            Text(_formatSize(m['media_size'] ?? 0), style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
        ]),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _tickIcon(Map<String, dynamic> msg) {
    if (msg['is_read'] == true) return const Icon(Icons.done_all, size: 13, color: Colors.blue);
    if (msg['is_delivered'] == true) return const Icon(Icons.done_all, size: 13, color: Colors.white54);
    return const Icon(Icons.done, size: 13, color: Colors.white38);
  }

  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141420),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _attachOption(Icons.image, 'Photo', () { Navigator.pop(context); _sendMedia('image'); }),
          _attachOption(Icons.videocam, 'Video', () { Navigator.pop(context); _sendMedia('video'); }),
          _attachOption(Icons.insert_drive_file, 'File', () { Navigator.pop(context); _sendMedia('file'); }),
        ]),
      ),
    );
  }

  Widget _attachOption(IconData icon, String label, VoidCallback onTap) {
    final accent = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: accent.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(icon, color: accent, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    );
  }

  @override
  void dispose() {
    _setOnline(false);
    _onlineTimer?.cancel();
    _msgSub?.cancel();
    _onlineSub?.cancel();
    _audioPlayer.dispose();
    _recorder.dispose();
    _msgCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Stack(clipBehavior: Clip.none, children: [
            CircleAvatar(
              backgroundColor: accent.withOpacity(0.2),
              radius: 18,
              child: Text(_name[0].toUpperCase(),
                style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
            ),
            Positioned(bottom: 0, right: 0,
              child: Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: _theirOnline ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0A0A0F), width: 1.5),
                ),
              ),
            ),
          ]),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text(_theirOnline ? 'Online' : 'Offline',
              style: TextStyle(fontSize: 11, color: _theirOnline ? Colors.green : Colors.white38)),
          ]),
        ]),
        actions: [
          IconButton(icon: Icon(Icons.call, color: accent),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateRoomScreen()))),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _messages.length,
            itemBuilder: (_, i) {
              final m = _messages[i];
              final isMe = m['sender_number'] == _myNumber;
              return GestureDetector(
                onLongPress: () => _deleteMessage(m),
                child: Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                    decoration: BoxDecoration(
                      color: isMe ? accent : const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMessageContent(m, isMe),
                        if (isMe) ...[
                          const SizedBox(height: 2),
                          _tickIcon(m),
                        ],
                      ]),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          color: const Color(0xFF0A0A0F),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.attach_file, color: Colors.white54),
              onPressed: _showAttachMenu,
            ),
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1A1A2E),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _sendText(),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onLongPress: _startRecording,
              onLongPressUp: _stopRecording,
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: _isRecording ? Colors.red : accent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isRecording ? Icons.stop : (_msgCtrl.text.isEmpty ? Icons.mic : Icons.send),
                  color: Colors.white, size: 20,
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
