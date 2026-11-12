import 'package:flutter/material.dart';
import 'core.dart';

class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key});
  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  List<Map> apps = [];
  bool loading = true;
  String filter = 'Semua', query = '';

  static const filters = ['Semua', 'Pengguna', 'Sistem', 'Tersembunyi', 'Nonaktif'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final r = await ch.invokeListMethod<Map>('listApps') ?? [];
    r.sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));
    if (mounted) setState(() { apps = r; loading = false; });
  }

  // Tersembunyi = tidak punya ikon di launcher ATAU dinonaktifkan
  bool _hidden(Map a) => a['launcher'] == false || a['enabled'] == false;

  List<Map> get shown => apps.where((a) {
        final ok = switch (filter) {
          'Pengguna' => a['system'] == false,
          'Sistem' => a['system'] == true,
          'Tersembunyi' => _hidden(a),
          'Nonaktif' => a['enabled'] == false,
          _ => true,
        };
        final q = query.toLowerCase();
        return ok && (q.isEmpty || (a['name'] as String).toLowerCase().contains(q) || (a['package'] as String).contains(q));
      }).toList();

  void _actions(Map a) {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(a['name']), subtitle: Text('${a['package']}\nVersi ${a['version']} • ${fmt(a['size'])}'), isThreeLine: true),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Info aplikasi (hapus cache/data)'),
            onTap: () { Navigator.pop(c); ch.invokeMethod('openAppInfo', a['package']); },
          ),
          if (a['system'] == false)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Copot pemasangan'),
              onTap: () { Navigator.pop(c); ch.invokeMethod('uninstall', a['package']).then((_) => _load()); },
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = shown;
    return Scaffold(
      appBar: AppBar(title: const Text('Pengendali Aplikasi'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: TextField(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cari nama / package', border: OutlineInputBorder()),
                  onChanged: (v) => setState(() => query = v),
                ),
              ),
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    for (final f in filters)
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: ChoiceChip(label: Text(f), selected: filter == f, onSelected: (_) => setState(() => filter = f)),
                      ),
                  ],
                ),
              ),
              Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('${list.length} dari ${apps.length} aplikasi')),
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final a = list[i];
                    final tags = [
                      if (a['system'] == true) 'Sistem',
                      if (a['enabled'] == false) 'Nonaktif',
                      if (a['launcher'] == false) 'Tanpa ikon',
                    ].join(' • ');
                    return ListTile(
                      leading: CircleAvatar(child: Icon(a['system'] == true ? Icons.android : Icons.apps)),
                      title: Text(a['name']),
                      subtitle: Text('${a['package']}${tags.isEmpty ? '' : '\n$tags'}'),
                      isThreeLine: tags.isNotEmpty,
                      trailing: Text(fmt(a['size'])),
                      onTap: () => _actions(a),
                    );
                  },
                ),
              ),
            ]),
    );
  }
}
