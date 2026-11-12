import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'apps_screen.dart';
import 'core.dart';
import 'scan_screen.dart';
import 'splash.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Cleaner Pro',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF006A7A), useMaterial3: true),
        home: const SplashPage(next: Home()),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int ram = 0;

  @override
  void initState() {
    super.initState();
    _ram();
  }

  Future<void> _ram() async {
    final r = await ch.invokeMethod<int>('availRam') ?? 0;
    if (mounted) setState(() => ram = r);
  }

  void _open(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

  Future<void> _freeRam() async {
    final freed = await ch.invokeMethod<int>('freeRam') ?? 0;
    await _ram();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('RAM dibebaskan: ${fmt(freed)}')));
  }

  void _settings() {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Pengaturan')),
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('Izin akses semua file'),
            trailing: FilledButton(onPressed: () async { await askStorageAccess(); if (c.mounted) Navigator.pop(c); }, child: const Text('Atur')),
          ),
          const ListTile(leading: Icon(Icons.info_outline), title: Text('Cleaner Pro 1.0')),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
          MenuCard(
            icon: Icons.folder_off_outlined,
            title: 'PencariMayat',
            desc: 'Data milik aplikasi yang sudah dihapus.',
            onTap: () => _open(ScanScreen(
              title: 'PencariMayat',
              scan: scanCorpses,
              hint: 'Catatan: Android 11+ membatasi akses ke Android/data & obb, jadi hasil bisa terbatas.',
            )),
          ),
          MenuCard(
            icon: Icons.cached,
            title: 'Pembersih Cache',
            desc: 'Cache aplikasi yang bisa dihapus.',
            onTap: () => _open(ScanScreen(
              title: 'Pembersih Cache',
              scan: scanCache,
              hint: 'Cache aplikasi lain dibatasi sistem. Gunakan tombol di bawah untuk membersihkannya lewat pengaturan Android.',
              extra: OutlinedButton.icon(
                onPressed: () => ch.invokeMethod('openStorageSettings'),
                icon: const Icon(Icons.settings),
                label: const Text('Buka pengaturan penyimpanan'),
              ),
            )),
          ),
          MenuCard(
            icon: Icons.history,
            title: 'File Sementara',
            desc: 'File .tmp, .log, .bak, dan sejenisnya.',
            onTap: () => _open(const ScanScreen(title: 'File Sementara', scan: scanTemp)),
          ),
          MenuCard(
            icon: Icons.delete_sweep_outlined,
            title: 'File Tidak Berguna',
            desc: 'File kosong, folder kosong, APK lama, thumbnail.',
            onTap: () => _open(const ScanScreen(title: 'File Tidak Berguna', scan: scanUseless)),
          ),
          MenuCard(
            icon: Icons.difference_outlined,
            title: 'Deduplikator',
            desc: 'Temukan data duplikat pada perangkat Anda.',
            onTap: () => _open(const ScanScreen(
              title: 'Deduplikator',
              scan: scanDuplicates,
              hint: 'File tertua dipertahankan, salinannya yang ditandai untuk dihapus.',
            )),
          ),
          MenuCard(
            icon: Icons.apps,
            title: 'Pengendali Aplikasi',
            desc: 'Aplikasi terpasang di perangkat Anda.',
            action: 'Lihat',
            actionIcon: Icons.visibility_outlined,
            onTap: () => _open(const AppsScreen()),
          ),
        ]),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: _freeRam,
        tooltip: 'Bersihkan RAM',
        child: const Icon(Icons.memory),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Padding(padding: const EdgeInsets.only(left: 12), child: Text('RAM kosong\n${fmt(ram)}', style: Theme.of(context).textTheme.labelSmall)),
          IconButton(onPressed: _settings, icon: const Icon(Icons.settings)),
        ]),
      ),
    );
  }
}

class MenuCard extends StatelessWidget {
  final IconData icon, actionIcon;
  final String title, desc, action;
  final VoidCallback onTap;
  const MenuCard({
    super.key,
    required this.icon,
    required this.title,
    required this.desc,
    required this.onTap,
    this.action = 'Pindai',
    this.actionIcon = Icons.manage_search,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      elevation: 1,
      color: t.colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon), const SizedBox(width: 16), Expanded(child: Text(title, style: t.textTheme.titleLarge))]),
          const SizedBox(height: 8),
          Text(desc, style: t.textTheme.bodyLarge),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: action == 'Pindai'
                ? FilledButton.icon(onPressed: onTap, icon: Icon(actionIcon), label: Text(action))
                : TextButton.icon(onPressed: onTap, icon: Icon(actionIcon), label: Text(action)),
          ),
        ]),
      ),
    );
  }
}
