import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Offline-signed Pro unlock codes.
///
/// Format: BD-{YYYYMMDD(expiry)}-{XXXX(checksum)}-{RANDOM}
/// Checksum = HMAC-SHA256(secret, payload), first 4 hex chars, uppercase.
/// No server needed; only the seller (JD Hub) knows the secret.
const String _proSecret = 'JDHub-BizDocs-2026-ProKey';

String? validateProCode(String code) {
  final clean = code.trim().toUpperCase();
  final m = RegExp(r'^BD-(\d{8})-([0-9A-F]{4})-([A-Z0-9]{4,8})$')
      .firstMatch(clean);
  if (m == null) return null;
  final payload = 'BD-${m.group(1)}-${m.group(3)}';
  final expected = _checksum(payload);
  if (m.group(2) != expected) return null;
  final exp = DateTime.parse(
      '${m.group(1)!.substring(0, 4)}-${m.group(1)!.substring(4, 6)}-${m.group(1)!.substring(6, 8)}');
  return exp.millisecondsSinceEpoch.toString() + '|' + clean;
}

int expiryMillis(String code) =>
    int.parse(validateProCode(code)!.split('|').first);

String _checksum(String payload) {
  final h = Hmac(sha256, utf8.encode(_proSecret));
  return h.convert(utf8.encode(payload)).toString().substring(0, 4).toUpperCase();
}

/// The fixed demo/test code — keep working for early adopters.
const String kLegacyProCode = 'BIZPRO-2026';

bool isLegacyCode(String code) => code.trim().toUpperCase() == kLegacyProCode;

// ---------- Generator (for JD Hub admin use inside the app) ----------

const String _adminPin = '2607'; // JD Hub admin PIN — change before launch

String generateProCode(DateTime expiry) {
  final rand = Random.secure();
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random =
      List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  final ymd = DateFormat('yyyyMMdd').format(expiry);
  final payload = 'BD-$ymd-$random';
  return 'BD-$ymd-${_checksum(payload)}-$random';
}

class GeneratedCode {
  final String code;
  final int expiry;
  final int createdAt;
  final String? note;
  GeneratedCode(
      {required this.code,
      required this.expiry,
      required this.createdAt,
      this.note});

  Map<String, dynamic> toJson() =>
      {'code': code, 'expiry': expiry, 'created_at': createdAt, 'note': note};
  factory GeneratedCode.fromJson(Map<String, dynamic> m) => GeneratedCode(
      code: m['code'] as String,
      expiry: m['expiry'] as int,
      createdAt: m['created_at'] as int,
      note: m['note'] as String?);
}

class ProCodeStore {
  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/pro_codes.json');
  }

  static Future<List<GeneratedCode>> list() async {
    final f = await _file();
    if (!f.existsSync()) return [];
    try {
      final arr = jsonDecode(await f.readAsString()) as List;
      return arr
          .map((e) => GeneratedCode.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<GeneratedCode> create(DateTime expiry, {String? note}) async {
    final codes = await list();
    final gc = GeneratedCode(
        code: generateProCode(expiry),
        expiry: expiry.millisecondsSinceEpoch,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        note: note);
    codes.insert(0, gc);
    await (await _file())
        .writeAsString(jsonEncode(codes.map((c) => c.toJson()).toList()));
    return gc;
  }

  static Future<void> exportShare() async {
    final codes = await list();
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/bizdocs_pro_codes.csv');
    final buf = StringBuffer('code,expires,created,note\n');
    for (final c in codes) {
      final df = DateFormat('yyyy-MM-dd');
      buf.writeln([
        c.code,
        df.format(DateTime.fromMillisecondsSinceEpoch(c.expiry)),
        df.format(DateTime.fromMillisecondsSinceEpoch(c.createdAt)),
        c.note ?? ''
      ].join(','));
    }
    await f.writeAsString(buf.toString());
    await SharePlus.instance.share(ShareParams(files: [XFile(f.path)]));
  }
}

/// Persisted in app settings: seller mode unlocked via admin PIN.
Future<bool> checkAdminPin(String pin) async => pin == _adminPin;

class ProCodeImporter {
  /// Import a codes file exported on another device (keeps seller's list in sync).
  static Future<int> importCodes() async {
    final picked = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: ['json', 'csv']);
    if (picked.isEmpty || picked.single.path == null) return 0;
    final content = await File(picked.single.path!).readAsString();
    var added = 0;
    try {
      if (picked.single.path!.endsWith('.json')) {
        final arr = jsonDecode(content) as List;
        final existing = (await ProCodeStore.list()).map((c) => c.code).toSet();
        final codes = await ProCodeStore.list();
        for (final e in arr) {
          final gc = GeneratedCode.fromJson(e as Map<String, dynamic>);
          if (!existing.contains(gc.code)) {
            codes.add(gc);
            added++;
          }
        }
        await (await ProCodeStore._file())
            .writeAsString(jsonEncode(codes.map((c) => c.toJson()).toList()));
      }
    } catch (e) {
      debugPrint('importCodes: $e');
    }
    return added;
  }
}
