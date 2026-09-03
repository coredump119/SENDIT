/// 平台无关的"一张图"：[id] 在桌面 / 手机是文件路径，在网页是内存里的键。
class PickedImage {
  final String id;
  final String name;
  final DateTime? mtime;
  const PickedImage({required this.id, required this.name, this.mtime});
}

/// 拖入结果：要么是一个文件夹，要么是一批图片
class DropResult {
  final String? folder;
  final List<PickedImage> images;
  const DropResult({this.folder, this.images = const []});
}

class ExportSummary {
  final String outputDir;
  final List<String> folders;
  final int filesCopied;
  const ExportSummary({required this.outputDir, required this.folders, required this.filesCopied});
}
