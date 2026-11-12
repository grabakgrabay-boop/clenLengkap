import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

const ch = MethodChannel('cleaner');
const root = '/storage/emulated/0';

class Item {
  final String path, label;
  final int size;
  final bool isDir;
  bool selected = true;
  Item(this.path, this.label, this.size, {this.isDir = false});
  String get name => path.split('/').last;
}

String fmt(int b) {
  if (b < 1024) return '$b B';
  if (b < 1048576) return '${(b / 1024).toStringAsFixed(1)} KB';
  if (b < 1073741824) return '${(b / 1048576).toStringAsFixed(1)} MB';
  return '${(b / 1073741824).toStringAsFixed(2)} GB';
}

Future<bool> hasStorageAccess() => Permission.manageExternalStorage.isGranted;
Future<bool> askStorageAccess() async => (await Permission.manageExternalStorage.request()).isGranted;

Future<int> dirSize(Directory d) async {
  int t = 0;
  try {
    await for (final f in d.list(recursive: true, followLinks: false)) {
      if (f is File) t += await f.length();
    }
  } catch (_) {}
  return t;
}

Stream<FileSystemEntity> walkAll(Directory d) async* {
  List<FileSystemEntity> kids;
  try {
    kids = await d.list(followLinks: false).toList();
  } catch (_) {
    return;
  }
  for (final e in kids) {
    yield e;
    if (e is Directory && e.path != '$root/Android') yield* walkAll(e);
  }
}

String _ext(String name) => name.contains('.') ? name.split('.').last.toLowerCase() : '';

// ---------- 1. PencariMayat: sisa data aplikasi yang sudah dihapus ----------
Future<List<Item>> scanCorpses() async {
  final apps = await ch.invokeListMethod<Map>('listApps') ?? [];
  final installed = apps.map((a) => a['package'] as String).toSet();
  final out = <Item>[];
  for (final base in ['Android/data', 'Android/obb', 'Android/media']) {
    try {
      await for (final e in Directory('$root/$base').list(followLinks: false)) {
        final n = e.path.split('/').last;
        if (e is Directory && n.contains('.') && !installed.contains(n)) {
          out.add(Item(e.path, 'Sisa aplikasi dihapus ($base)', await dirSize(e), isDir: true));
        }
      }
    } catch (_) {} // Android 11+ membatasi Android/data & obb
  }
  return out;
}

// ---------- 2. Cache ----------
Future<List<Item>> scanCache() async {
  final out = <Item>[];
  final dirs = [await getTemporaryDirectory(), ...?await getExternalCacheDirectories()];
  for (final d in dirs) {
    try {
      await for (final e in d.list()) {
        out.add(Item(e.path, 'Cache aplikasi ini', e is File ? await e.length() : await dirSize(e as Directory), isDir: e is Directory));
      }
    } catch (_) {}
  }
  try {
    await for (final e in Directory('$root/Android/data').list()) {
      final c = Directory('${e.path}/cache');
      if (await c.exists()) {
        final s = await dirSize(c);
        if (s > 0) out.add(Item(c.path, 'Cache ${e.path.split('/').last}', s, isDir: true));
      }
    }
  } catch (_) {}
  return out;
}

// ---------- 3. File sementara ----------
Future<List<Item>> scanTemp() async {
  const tmp = {'tmp', 'temp', 'log', 'bak', 'old', 'chk', 'dmp', 'thumbdata', 'cache'};
  final out = <Item>[];
  await for (final e in walkAll(Directory(root))) {
    if (e is File) {
      final n = e.path.split('/').last;
      if (tmp.contains(_ext(n)) || n.endsWith('~') || n.startsWith('.tmp')) {
        out.add(Item(e.path, 'File sementara/log', await e.length()));
      }
    }
  }
  return out;
}

// ---------- 4. File tidak berguna ----------
Future<List<Item>> scanUseless() async {
  final out = <Item>[];
  await for (final e in walkAll(Directory(root))) {
    final n = e.path.split('/').last;
    if (e is File) {
      final size = await e.length();
      if (_ext(n) == 'apk') {
        out.add(Item(e.path, 'APK installer lama', size));
      } else if (size == 0) {
        out.add(Item(e.path, 'File kosong', 0));
      } else if (e.parent.path.endsWith('.thumbnails') || e.parent.path.endsWith('LOST.DIR')) {
        out.add(Item(e.path, 'Thumbnail/LOST.DIR', size));
      }
    } else if (e is Directory) {
      try {
        if (await e.list().isEmpty) out.add(Item(e.path, 'Folder kosong', 0, isDir: true));
      } catch (_) {}
    }
  }
  return out;
}

// ---------- 5. Deduplikator ----------
Future<List<Item>> scanDuplicates() async {
  final bySize = <int, List<File>>{};
  await for (final e in walkAll(Directory(root))) {
    if (e is File) {
      final s = await e.length();
      if (s >= 50 * 1024) bySize.putIfAbsent(s, () => []).add(e);
    }
  }
  final out = <Item>[];
  for (final group in bySize.values.where((g) => g.length > 1)) {
    final byHash = <String, List<File>>{};
    for (final f in group) {
      try {
        final h = (await md5.bind(f.openRead()).first).toString();
        byHash.putIfAbsent(h, () => []).add(f);
      } catch (_) {}
    }
    for (final dup in byHash.values.where((g) => g.length > 1)) {
      dup.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
      final keep = dup.first.path.split('/').last;
      for (final f in dup.skip(1)) {
        out.add(Item(f.path, 'Duplikat dari $keep', await f.length()));
      }
    }
  }
  out.sort((a, b) => b.size.compareTo(a.size));
  return out;
}
