/// 从文件名里识别编号，或按列表顺序自动编号。纯逻辑，不碰文件系统。
enum NumberRule {
  /// 文件名第一段数字
  firstNumber,
  /// 文件名最后一段数字
  lastNumber,
  /// 忽略文件名，按传入顺序 1..N
  sequential,
}

class IndexedImage {
  final String path;
  final String name;
  final int? number;
  const IndexedImage({required this.path, required this.name, this.number});
}

class ImageIndex {
  final List<IndexedImage> images;
  /// n -> path（仅唯一编号）
  final Map<int, String> byNumber;
  /// n -> 多个文件
  final Map<int, List<String>> duplicates;
  final List<IndexedImage> unnumbered;
  final int maxNumber;
  final List<int> missing;

  const ImageIndex({
    required this.images,
    required this.byNumber,
    required this.duplicates,
    required this.unnumbered,
    required this.maxNumber,
    required this.missing,
  });

  bool get ok => duplicates.isEmpty && byNumber.isNotEmpty;
}

class ImageIndexer {
  static const extensions = {
    'png', 'jpg', 'jpeg', 'webp', 'gif', 'heic', 'heif', 'bmp', 'tif', 'tiff'
  };
  static final _num = RegExp(r'\d+');

  final NumberRule rule;
  const ImageIndexer({this.rule = NumberRule.firstNumber});

  static bool isImage(String name) {
    final i = name.lastIndexOf('.');
    if (i < 0) return false;
    return extensions.contains(name.substring(i + 1).toLowerCase());
  }

  int? numberOf(String name) {
    final stem = name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
    final all = _num.allMatches(stem).toList();
    if (all.isEmpty) return null;
    final m = rule == NumberRule.firstNumber ? all.first : all.last;
    return int.tryParse(m[0]!);
  }

  /// [paths] 是文件完整路径列表；用 [nameOf] 取文件名（默认取最后一个 / 后的部分）。
  ImageIndex index(List<String> paths, {String Function(String)? nameOf}) {
    nameOf ??= (p) => p.split(RegExp(r'[/\\]')).last;
    final images = <IndexedImage>[];
    final grouped = <int, List<String>>{};
    final unnumbered = <IndexedImage>[];

    var seq = 0;
    for (final p in paths) {
      final name = nameOf(p);
      if (!isImage(name)) continue;
      final n = rule == NumberRule.sequential ? ++seq : numberOf(name);
      final img = IndexedImage(path: p, name: name, number: n);
      images.add(img);
      if (n == null || n < 1) {
        unnumbered.add(img);
      } else {
        grouped.putIfAbsent(n, () => []).add(p);
      }
    }

    final byNumber = <int, String>{};
    final duplicates = <int, List<String>>{};
    grouped.forEach((n, ps) {
      if (ps.length == 1) {
        byNumber[n] = ps.first;
      } else {
        duplicates[n] = ps;
      }
    });

    final max = grouped.keys.fold<int>(0, (a, b) => a > b ? a : b);
    final missing = [for (var n = 1; n <= max; n++) if (!grouped.containsKey(n)) n];

    images.sort((a, b) {
      final an = a.number ?? 1 << 30, bn = b.number ?? 1 << 30;
      return an != bn ? an.compareTo(bn) : a.name.compareTo(b.name);
    });

    return ImageIndex(
      images: images,
      byNumber: byNumber,
      duplicates: duplicates,
      unnumbered: unnumbered,
      maxNumber: max,
      missing: missing,
    );
  }
}
