import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';

class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});
  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    final res = await auth.searchUsers(q);
    setState(() { _results = res; _loading = false; });
  }

  Future<void> _addAndChat(Map<String, dynamic> user) async {
    final auth = context.read<AuthService>();
    // Save as contact
    final existing = await _supabase
        .from('contacts')
        .select()
        .eq('owner_id', auth.currentUser!.id)
        .eq('contact_number', user['call_number'])
        .maybeSingle();

    if (existing == null) {
      await _supabase.from('contacts').insert({
        'owner_id': auth.currentUser!.id,
        'contact_number': user['call_number'],
        'contact_name': user['display_name'] ?? user['unique_uid'],
        'contact_uid': user['unique_uid'],
      });
    }

    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatScreen(contact: {
        'contact_number': user['call_number'],
        'contact_name': user['display_name'] ?? user['unique_uid'],
        'contact_uid': user['unique_uid'],
      }),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('Search Users')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by name or user ID...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white38),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _results = []);
                      },
                    )
                  : null,
            ),
            onChanged: _search,
          ),
        ),
        if (_loading)
          const LinearProgressIndicator()
        else
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _searchCtrl.text.isEmpty
                          ? 'Search by name or user ID'
                          : 'No users found',
                      style: const TextStyle(color: Colors.white38),
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final u = _results[i];
                      final online = u['is_online'] ?? false;
                      final name = u['display_name'] ?? 'Unknown';
                      final uid = u['unique_uid'] ?? '';
                      return ListTile(
                        leading: Stack(clipBehavior: Clip.none, children: [
                          CircleAvatar(
                            backgroundColor: accent.withOpacity(0.2),
                            child: Text(
                              name[0].toUpperCase(),
                              style: TextStyle(color: accent, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              width: 10, height: 10,
                              decoration: BoxDecoration(
                                color: online ? Colors.green : Colors.grey,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF0A0A0F), width: 1.5),
                              ),
                            ),
                          ),
                        ]),
                        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'ID: $uid  •  ${online ? "Online" : "Offline"}',
                          style: TextStyle(
                            color: online ? Colors.green : Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: () => _addAndChat(u),
                          child: Text('Message', style: TextStyle(color: accent)),
                        ),
                        onTap: () => _addAndChat(u),
                      );
                    },
                  ),
          ),
      ]),
    );
  }
}
