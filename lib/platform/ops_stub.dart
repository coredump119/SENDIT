import 'package:file_selector/file_selector.dart' show XFile;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../core/core.dart';
import 'picked.dart';

bool get isWeb => false;
bool get isDesktop => false;
bool get isMobile => false;
bool get isAndroid => false;
bool get canPickFolder => false;

Future<String?> pickFolder() async => null;
Future<List<PickedImage>> listFolder(String dir) async => [];
Future<List<PickedImage>> pickImages({void Function(int done, int total)? onProgress}) async => [];
Future<DropResult> fromDrop(List<XFile> files, {void Function(int done, int total)? onProgress}) async => const DropResult();
ImageProvider imageProvider(String id) => throw UnsupportedError('stub');
Future<ExportSummary> exportFolders({required Allocation allocation, required ImageIndex images, required String outputDir, bool rename = true, void Function(int, int)? onProgress}) => throw UnsupportedError('stub');
Future<void> downloadZip({required Allocation allocation, required ImageIndex images, bool rename = true, String zipName = 'sendit.zip'}) => throw UnsupportedError('stub');
Future<int> saveToPhotos(PersonResult person, ImageIndex images, {String? album, bool rename = true}) => throw UnsupportedError('stub');
Future<void> revealFolder(String path) async {}
String? defaultOutputDir(String? imageDir) => null;
Future<Uint8List> readBytes(String id) => throw UnsupportedError('stub');
Future<String?> saveImageBytes(Uint8List bytes, String name, {String? dir}) => throw UnsupportedError('stub');
