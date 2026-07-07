import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
import 'call/create_room_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});
  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final auth = context.read<AuthService>();
    final res = await _supabase
        .from('contacts')
        .select()
        .eq('owner_id', auth.currentUser!.id)
        .order('contact_name');
    setState(() { _contacts = List<Map<String, dynamic>>.from(res); _loading = false; });
  }

  Future<void> _addContact() async {
    final nameCtrl = TextEditingController();
    final numCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141420),
        title: const Text('Add Contact', style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Name (optional)')),
          const SizedBox(height: 12),
          TextField(controller: numCtrl, style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '20-digit Number')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (numCtrl.text.length != 20) return;
              final auth = context.read<AuthService>();
              // Check if number exists
              final res = await _supabase.from('users')
                  .select('id').eq('call_number', numCtrl.text).maybeSingle();
              if (res == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User not found!')));
                return;
              }
              await _supabase.from('contacts').insert({
                'owner_id': auth.currentUser!.id,
                'contact_number': numCtrl.text,
                'contact_name': nameCtrl.text.isEmpty ? numCtrl.text : nameCtrl.text,
              });
              Navigator.pop(context);
              _loadContacts();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _callContact(Map<String, dynamic> contact) async {
    final auth = context.read<AuthService>();
    final room = context.read<RoomService>();
    final code = await room.createRoom(auth.currentUser!);
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CreateRoomScreen(prefilledCode: code, targetNumber: contact['contact_number']),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addContact,
        backgroundColor: accent,
        child: const Icon(Icons.person_add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? const Center(child: Text('No contacts yet.\nTap + to add.', textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  itemCount: _contacts.length,
                  itemBuilder: (_, i) {
                    final c = _contacts[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: accent.withOpacity(0.2),
                        child: Text(c['contact_name'][0].toUpperCase(),
                          style: TextStyle(color: accent)),
                      ),
                      title: Text(c['contact_name'], style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        '${c['contact_number'].substring(0,3)}***${c['contact_number'].substring(17)}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      trailing: IconButton(
                        icon: Icon(Icons.call, color: accent),
                        onPressed: () => _callContact(c),
                      ),
                      onLongPress: () async {
                        await _supabase.from('contacts').delete().eq('id', c['id']);
                        _loadContacts();
                      },
                    );
                  },
                ),
    );
  }
}
