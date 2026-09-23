/// 等高行拼图排版（纯 Dart，可单测）。
/// 输入每张图的宽高比，输出每张图在画布上的位置；按编号顺序、保持比例、混排横竖图。
class CollageItem {
  final int number;
  final double width;
  final double height;
  const CollageItem({required this.number, required this.width, required this.height});
  double get ratio => width / height;
}

class Placement {
  final int number;
  final double x, y, w, h;
  const Placement(this.number, this.x, this.y, this.w, this.h);
}

class CollagePage {
  final List<Placement> items;
  final double width;
  final double height;
  const CollagePage({required this.items, required this.width, required this.height});
}

class CollageLayout {
  final double canvasWidth;
  /// 目标行高：越大每行张数越少。2000 宽 + 880 高 → 竖图一行最多 4 张
  final double targetRowHeight;
  final double gap;
  final double margin;
  final double headerHeight;
  final int maxPerPage;
  /// 比例夹在 [minRatio, maxRatio]，超出的按上限占位（绘制时居中留白）
  final double minRatio;
  final double maxRatio;

  const CollageLayout({
    this.canvasWidth = 2000,
    this.targetRowHeight = 880,
    this.gap = 28,
    this.margin = 44,
    this.headerHeight = 130,
    this.maxPerPage = 8,
    this.minRatio = 9 / 16,
    this.maxRatio = 16 / 9,
  });

  double clampRatio(double r) => r.clamp(minRatio, maxRatio).toDouble();

  /// 分页：页数 = ceil(n / maxPerPage)，每页尽量均匀（14 张 → 7 + 7，而不是 12 + 2）
  List<CollagePage> paginate(List<CollageItem> items) {
    if (items.isEmpty) return const [];
    final pageCount = (items.length + maxPerPage - 1) ~/ maxPerPage;
    final perPage = (items.length + pageCount - 1) ~/ pageCount;
    final pages = <CollagePage>[];
    for (var i = 0; i < items.length; i += perPage) {
      pages.add(layout(items.sublist(i, (i + perPage).clamp(0, items.length))));
    }
    return pages;
  }

  /// 单页：等高行排版，行断点用 DP 全局求最优（每页 ≤ 8 张，开销可忽略）。
  /// 每行整体缩放到填满宽度，行高越接近目标越好；超过目标（图被放大、单张撑满）按 2 倍惩罚。
  /// 最后一行不拉伸（左对齐，行高 ≤ 目标）。
  CollagePage layout(List<CollageItem> items) {
    final innerW = canvasWidth - margin * 2;
    final out = <Placement>[];
    if (items.isEmpty) return CollagePage(items: out, width: canvasWidth, height: margin * 2 + headerHeight);

    final n = items.length;
    final ratios = items.map((e) => clampRatio(e.ratio)).toList();
    final prefix = List<double>.filled(n + 1, 0);
    for (var i = 0; i < n; i++) {
      prefix[i + 1] = prefix[i] + ratios[i];
    }

    // 行 [i, j) 填满宽度时的行高
    double rowH(int i, int j) => (innerW - gap * (j - i - 1)) / (prefix[j] - prefix[i]);
    double cost(double h) {
      final d = h > targetRowHeight ? (h - targetRowHeight) * 2 : targetRowHeight - h;
      return d * d;
    }

    // best[j]：前 j 张的最小代价；cut[j]：最后一行起点
    final best = List<double>.filled(n + 1, double.infinity);
    final cut = List<int>.filled(n + 1, 0);
    best[0] = 0;
    for (var j = 1; j <= n; j++) {
      for (var i = j - 1; i >= 0; i--) {
        final h = rowH(i, j);
        // 尾行：自然高度不超过目标就不拉伸，代价 0；否则按普通行算
        final isTail = j == n;
        final c = (isTail && h >= targetRowHeight) ? 0.0 : cost(h);
        // 一行最多塞到行高低于 0.45 倍目标为止，再往里塞没意义
        if (h < targetRowHeight * 0.45 && j - i > 1) break;
        final total = best[i] + c;
        if (total < best[j]) {
          best[j] = total;
          cut[j] = i;
        }
      }
    }

    final breaks = <int>[];
    for (var j = n; j > 0; j = cut[j]) {
      breaks.insert(0, cut[j]);
    }
    var y = margin + headerHeight;
    for (var r = 0; r < breaks.length; r++) {
      final i = breaks[r];
      final j = r + 1 < breaks.length ? breaks[r + 1] : n;
      var h = rowH(i, j);
      if (j == n && h > targetRowHeight) h = targetRowHeight; // 尾行不拉伸
      var x = margin;
      for (var k = i; k < j; k++) {
        final w = h * ratios[k];
        out.add(Placement(items[k].number, x, y, w, h));
        x += w + gap;
      }
      y += h + gap;
    }
    return CollagePage(items: out, width: canvasWidth, height: y - gap + margin);
  }
}
