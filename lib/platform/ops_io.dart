import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;

import '../core/core.dart';
import 'picked.dart';

bool get isWeb => false;
bool get isDesktop => Platform.isMacOS || Platform.isWindows || Platform.isLinux;
bool get isMobile => Platform.isIOS || Platform.isAndroid;
bool get isAndroid => Platform.isAndroid;
bool get canPickFolder => isDesktop;

Future<String?> pickFolder() => getDirectoryPath();

Future<PickedImage> _picked(String path) async {
  DateTime? m;
  try {
    m = (await File(path).stat()).modified;
  } catch (_) {}
  return PickedImage(id: path, name: p.basename(path), mtime: m);
}

Future<List<PickedImage>> listFolder(String dir) async {
  final out = <PickedImage>[];
  await for (final e in Directory(dir).list(followLinks: false)) {
    if (e is File && ImageIndexer.isImage(p.basename(e.path))) out.add(await _picked(e.path));
  }
  out.sort((a, b) => a.name.compareTo(b.name));
  return out;
}

Future<List<PickedImage>> pickImages({void Function(int done, int total)? onProgress}) async {
  if (isMobile) {
    throw UnsupportedError('手机端请使用应用内相册（GalleryPickerPage）');
  }
  final files = await openFiles(acceptedTypeGroups: [
    XTypeGroup(label: '图片', extensions: ImageIndexer.extensions.toList()),
  ]);
  final out = <PickedImage>[];
  for (var i = 0; i < files.length; i++) {
    out.add(await _picked(files[i].path));
    onProgress?.call(i + 1, files.length);
  }
  return out;
}

Future<DropResult> fromDrop(List<XFile> files, {void Function(int done, int total)? onProgress}) async {
  if (files.isEmpty) return const DropResult();
  if (files.length == 1 && FileSystemEntity.isDirectorySync(files.first.path)) {
    return DropResult(folder: files.first.path);
  }
  return DropResult(images: [
    for (final f in files)
      if (!FileSystemEntity.isDirectorySync(f.path) && ImageIndexer.isImage(p.basename(f.path))) await _picked(f.path),
  ]);
}

ImageProvider imageProvider(String id) => FileImage(File(id));

/// 桌面：把图片按人复制到子文件夹。只复制，不移动、不删除。
Future<ExportSummary> exportFolders({
  required Allocation allocation,
  required ImageIndex images,
  required String outputDir,
  bool rename = true,
  void Function(int, int)? onProgress,
}) async {
  final folders = <String>[];
  var copied = 0;
  final total = allocation.people.fold<int>(0, (s, x) => s + x.got.length) + allocation.unclaimed.length;

  Future<void> copyGroup(String folder, List<int> numbers) async {
    if (numbers.isEmpty) return;
    final dir = Directory(p.join(outputDir, folder));
    await dir.create(recursive: true);
    folders.add(folder);
    for (final n in numbers) {
      final src = images.byNumber[n];
      if (src == null) continue;
      final srcName = p.basename(src);
      final dstName = rename ? Report.fileNameForNumber(n, srcName, allocation.maxNumber) : srcName;
      await File(src).copy(p.join(dir.path, dstName));
      copied++;
      onProgress?.call(copied, total);
    }
  }

  for (final person in allocation.people) {
    await copyGroup(Report.folderName(person), person.got);
  }
  await copyGroup('_未认领 (${allocation.unclaimed.length}张)', allocation.unclaimed);
  await File(p.join(outputDir, '_分配公告.txt')).writeAsString(Report.announcement(allocation));
  final review = Report.reviewText(allocation);
  if (review != null) await File(p.join(outputDir, '_需人工确认.txt')).writeAsString(review);
  return ExportSummary(outputDir: outputDir, folders: folders, filesCopied: copied);
}

Future<void> downloadZip({required Allocation allocation, required ImageIndex images, bool rename = true, String zipName = 'sendit.zip'}) =>
    throw UnsupportedError('桌面版请使用文件夹导出');

/// 手机：把某人的原图保存到系统相册。[album] 为 null 时只进"最近项目"。
Future<int> saveToPhotos(PersonResult person, ImageIndex images, {String? album, bool rename = true}) async {
  if (!await Gal.hasAccess(toAlbum: album != null)) {
    await Gal.requestAccess(toAlbum: album != null);
  }
  final tmp = Directory(p.join(Directory.systemTemp.path, 'sendit_save'));
  await tmp.create(recursive: true);
  var n = 0;
  for (final num in person.got) {
    final src = images.byNumber[num];
    if (src == null) continue;
    var path = src;
    if (rename) {
      path = p.join(tmp.path, Report.fileNameForNumber(num, p.basename(src), images.maxNumber));
      await File(src).copy(path);
    }
    await Gal.putImage(path, album: album);
    n++;
  }
  return n;
}

Future<void> revealFolder(String path) async {
  if (Platform.isMacOS) {
    await Process.run('open', [path]);
  } else if (Platform.isWindows) {
    await Process.run('explorer', [path]);
  } else if (Platform.isLinux) {
    await Process.run('xdg-open', [path]);
  }
}

String? defaultOutputDir(String? imageDir) => imageDir == null ? null : p.join(imageDir, '_分发');

Future<Uint8List> readBytes(String id) => File(id).readAsBytes();

/// 保存生成的图片：桌面写入 [dir]，手机存相册。返回文件路径（手机为 null）。
Future<String?> saveImageBytes(Uint8List bytes, String name, {String? dir}) async {
  if (isMobile) {
    await Gal.putImageBytes(bytes, name: name.replaceAll(RegExp(r'\.(jpe?g|png)$'), ''));
    return null;
  }
  final d = Directory(dir ?? p.join(Directory.systemTemp.path, 'sendit'));
  await d.create(recursive: true);
  final f = File(p.join(d.path, name));
  await f.writeAsBytes(bytes);
  return f.path;
}
