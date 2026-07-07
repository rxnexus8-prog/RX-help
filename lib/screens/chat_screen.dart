import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
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
  List<Map<String, dynamic>> _messages = [];
  StreamSubscription? _sub;

  String get _myNumber => context.read<AuthService>().currentUser!.callNumber;
  String get _theirNumber => widget.contact['contact_number'];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _listenMessages();
  }

  Future<void> _loadMessages() async {
    final res = await _supabase
        .from('messages')
        .select()
        .or('and(sender_number.eq.$_myNumber,receiver_number.eq.$_theirNumber),and(sender_number.eq.$_theirNumber,receiver_number.eq.$_myNumber)')
        .order('created_at');
    setState(() => _messages = List<Map<String, dynamic>>.from(res));
    _scrollDown();
  }

  void _listenMessages() {
    _sub = _supabase.from('messages').stream(primaryKey: ['id']).listen((data) {
      final relevant = data.where((m) =>
        (m['sender_number'] == _myNumber && m['receiver_number'] == _theirNumber) ||
        (m['sender_number'] == _theirNumber && m['receiver_number'] == _myNumber)
      ).toList();
      setState(() => _messages = relevant);
      _scrollDown();
    });
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    final auth = context.read<AuthService>();
    await _supabase.from('messages').insert({
      'sender_id': auth.currentUser!.id,
      'sender_number': _myNumber,
      'receiver_number': _theirNumber,
      'content': text,
    });
  }

  Future<void> _startCall() async {
    final auth = context.read<AuthService>();
    final room = context.read<RoomService>();
    final code = await room.createRoom(auth.currentUser!);
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CreateRoomScreen(),
    ));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _msgCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final name = widget.contact['contact_name'];
    final masked = '$_theirNumber'.length >= 20
        ? '${_theirNumber.substring(0,3)}***${_theirNumber.substring(17)}'
        : _theirNumber;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(masked, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        ]),
        actions: [
          IconButton(
            icon: Icon(Icons.call, color: accent),
            onPressed: _startCall,
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(12),
            itemCount: _messages.length,
            itemBuilder: (_, i) {
              final m = _messages[i];
              final isMe = m['sender_number'] == _myNumber;
              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  decoration: BoxDecoration(
                    color: isMe ? accent : const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(m['content'],
                    style: TextStyle(color: isMe ? Colors.white : Colors.white70, fontSize: 14)),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: const Color(0xFF0A0A0F),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1A1A2E),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
