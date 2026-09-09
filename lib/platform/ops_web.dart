import 'dart:js_interop';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../core/core.dart';
import 'picked.dart';

bool get isWeb => true;
bool get isDesktop => false;
bool get isMobile => false;
bool get isAndroid => false;
bool get canPickFolder => false;

/// 网页：图片全部留在内存里，id = "序号/文件名"
final Map<String, Uint8List> _store = {};
var _seq = 0;

Future<PickedImage> _register(XFile f) async {
  final bytes = await f.readAsBytes();
  final id = '${_seq++}/${f.name}';
  _store[id] = bytes;
  DateTime? m;
  try {
    m = await f.lastModified();
  } catch (_) {}
  return PickedImage(id: id, name: f.name, mtime: m);
}

Future<String?> pickFolder() async => null;
Future<List<PickedImage>> listFolder(String dir) async => [];

Future<List<PickedImage>> pickImages({void Function(int done, int total)? onProgress}) async {
  final files = await openFiles(acceptedTypeGroups: [
    XTypeGroup(label: '图片', extensions: ImageIndexer.extensions.toList(), mimeTypes: const ['image/*']),
  ]);
  final imgs = files.where((f) => ImageIndexer.isImage(f.name)).toList();
  final out = <PickedImage>[];
  for (var i = 0; i < imgs.length; i++) {
    out.add(await _register(imgs[i]));
    onProgress?.call(i + 1, imgs.length);
  }
  return out;
}

Future<DropResult> fromDrop(List<XFile> files, {void Function(int done, int total)? onProgress}) async {
  final out = <PickedImage>[];
  final imgs = files.where((f) => ImageIndexer.isImage(f.name)).toList();
  for (var i = 0; i < imgs.length; i++) {
    out.add(await _register(imgs[i]));
    onProgress?.call(i + 1, imgs.length);
  }
  return DropResult(images: out);
}

ImageProvider imageProvider(String id) => MemoryImage(_store[id]!);

Future<ExportSummary> exportFolders({required Allocation allocation, required ImageIndex images, required String outputDir, bool rename = true, void Function(int, int)? onProgress}) =>
    throw UnsupportedError('网页版请下载 ZIP');

/// 网页：打成 ZIP 并触发浏览器下载。每人一个文件夹。
Future<void> downloadZip({required Allocation allocation, required ImageIndex images, bool rename = true, String zipName = 'sendit.zip'}) async {
  final archive = Archive();
  void add(String path, List<int> bytes) => archive.addFile(ArchiveFile.bytes(path, bytes));

  void addGroup(String folder, List<int> numbers) {
    for (final n in numbers) {
      final id = images.byNumber[n];
      final bytes = id == null ? null : _store[id];
      if (bytes == null) continue;
      final name = rename ? Report.fileNameForNumber(n, id!.split('/').last, allocation.maxNumber) : id!.split('/').last;
      add('$folder/$name', bytes);
    }
  }

  for (final person in allocation.people) {
    if (person.got.isNotEmpty) addGroup(Report.folderName(person), person.got);
  }
  if (allocation.unclaimed.isNotEmpty) addGroup('_未认领 (${allocation.unclaimed.length}张)', allocation.unclaimed);
  add('_分配公告.txt', _utf8(Report.announcement(allocation)));
  final review = Report.reviewText(allocation);
  if (review != null) add('_需人工确认.txt', _utf8(review));

  final zip = ZipEncoder().encodeBytes(archive);
  final blob = web.Blob([zip.toJS].toJS, web.BlobPropertyBag(type: 'application/zip'));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = zipName;
  web.document.body!.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
}

List<int> _utf8(String s) => s.codeUnits.any((c) => c > 0x7f) ? _encodeUtf8(s) : s.codeUnits;
List<int> _encodeUtf8(String s) {
  final out = <int>[];
  for (final r in s.runes) {
    if (r < 0x80) {
      out.add(r);
    } else if (r < 0x800) {
      out..add(0xC0 | (r >> 6))..add(0x80 | (r & 0x3F));
    } else if (r < 0x10000) {
      out..add(0xE0 | (r >> 12))..add(0x80 | ((r >> 6) & 0x3F))..add(0x80 | (r & 0x3F));
    } else {
      out..add(0xF0 | (r >> 18))..add(0x80 | ((r >> 12) & 0x3F))..add(0x80 | ((r >> 6) & 0x3F))..add(0x80 | (r & 0x3F));
    }
  }
  return out;
}

Future<int> saveToPhotos(PersonResult person, ImageIndex images, {String? album, bool rename = true}) => throw UnsupportedError('网页版不支持保存到相册');
Future<void> revealFolder(String path) async {}
String? defaultOutputDir(String? imageDir) => null;

Future<Uint8List> readBytes(String id) async => _store[id]!;

Future<String?> saveImageBytes(Uint8List bytes, String name, {String? dir}) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: name.endsWith('.png') ? 'image/png' : 'image/jpeg'));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body!.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
  return null;
}
