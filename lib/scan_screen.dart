import 'dart:io';
import 'package:flutter/material.dart';
import 'core.dart';

class ScanScreen extends StatefulWidget {
  final String title, hint;
  final Future<List<Item>> Function() scan;
  final Widget? extra;
  const ScanScreen({super.key, required this.title, required this.scan, this.hint = '', this.extra});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<Item> items = [];
  bool scanning = true, denied = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() { scanning = true; denied = false; });
    if (!await hasStorageAccess() && !await askStorageAccess()) {
      setState(() { scanning = false; denied = true; });
      return;
    }
    final r = await widget.scan();
    if (mounted) setState(() { items = r; scanning = false; });
  }

  int get selSize => items.where((i) => i.selected).fold(0, (a, b) => a + b.size);
  int get selCount => items.where((i) => i.selected).length;

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus permanen?'),
        content: Text('$selCount item (${fmt(selSize)}) akan dihapus dan tidak bisa dikembalikan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    int freed = 0;
    for (final i in items.where((i) => i.selected).toList()) {
      try {
        if (i.isDir) { await Directory(i.path).delete(recursive: true); } else { await File(i.path).delete(); }
        freed += i.size;
        items.remove(i);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Selesai! Dibebaskan ${fmt(freed)}')));
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (scanning) {
      body = const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Memindai...')]));
    } else if (denied) {
      body = Center(child: FilledButton(onPressed: _start, child: const Text('Beri izin akses semua file')));
    } else {
      body = Column(children: [
        if (widget.hint.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Text(widget.hint, style: Theme.of(context).textTheme.bodySmall)),
        if (widget.extra != null) Padding(padding: const EdgeInsets.all(12), child: widget.extra),
        ListTile(
          title: Text('${items.length} item ditemukan'),
          subtitle: Text('Dipilih: $selCount • ${fmt(selSize)}'),
          trailing: TextButton(
            onPressed: () => setState(() {
              final all = selCount != items.length;
              for (final i in items) { i.selected = all; }
            }),
            child: const Text('Pilih semua'),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('Tidak ada yang perlu dibersihkan 🎉'))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, k) {
                    final i = items[k];
                    return CheckboxListTile(
                      value: i.selected,
                      onChanged: (v) => setState(() => i.selected = v ?? false),
                      title: Text(i.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${i.label}\n${i.path}', maxLines: 2, overflow: TextOverflow.ellipsis),
                      secondary: Text(fmt(i.size)),
                      isThreeLine: true,
                    );
                  },
                ),
        ),
        if (items.isNotEmpty)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: selCount == 0 ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: Text('Hapus ($selCount • ${fmt(selSize)})'),
                ),
              ),
            ),
          ),
      ]);
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [IconButton(onPressed: scanning ? null : _start, icon: const Icon(Icons.refresh))]),
      body: body,
    );
  }
}
