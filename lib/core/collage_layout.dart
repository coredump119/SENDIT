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

  /// 单页：先定行数，再把图按比例总和均分到各行（线性分割 DP），每行填满宽度。
  /// 这样不会出现"7 张一行 + 1 张孤零零一行"。
  CollagePage layout(List<CollageItem> items) {
    final innerW = canvasWidth - margin * 2;
    final out = <Placement>[];
    if (items.isEmpty) return CollagePage(items: out, width: canvasWidth, height: margin * 2 + headerHeight);

    final ratios = items.map((e) => clampRatio(e.ratio)).toList();
    final total = ratios.fold(0.0, (a, b) => a + b);
    // 行数：按目标行高取整；同时保证每行不会挤得比 0.8 倍目标行高还矮
    final byTarget = (total * targetRowHeight / innerW).round();
    final byMinHeight = (total / (innerW / (targetRowHeight * 0.8))).ceil();
    final rows = (byTarget > byMinHeight ? byTarget : byMinHeight).clamp(1, items.length);
    final rowsOf = _partition(ratios, rows);

    var y = margin + headerHeight;
    var idx = 0;
    for (final count in rowsOf) {
      final slice = items.sublist(idx, idx + count);
      final sum = ratios.sublist(idx, idx + count).fold(0.0, (a, b) => a + b);
      final gaps = gap * (count - 1);
      var h = (innerW - gaps) / sum;
      // 行太少图时不无限放大（最多 1.3 倍目标行高），左对齐
      final maxH = targetRowHeight * 1.3;
      if (h > maxH) h = maxH;
      var x = margin;
      for (var i = 0; i < count; i++) {
        final w = h * ratios[idx + i];
        out.add(Placement(slice[i].number, x, y, w, h));
        x += w + gap;
      }
      y += h + gap;
      idx += count;
    }
    return CollagePage(items: out, width: canvasWidth, height: y - gap + margin);
  }

  /// 线性分割：把 [weights] 顺序切成 [k] 段，使最大段和最小。返回每段的元素个数。
  static List<int> _partition(List<double> weights, int k) {
    final n = weights.length;
    if (k >= n) return List.filled(n, 1);
    final prefix = List<double>.filled(n + 1, 0);
    for (var i = 0; i < n; i++) {
      prefix[i + 1] = prefix[i] + weights[i];
    }
    // dp[i][j]: 前 i 个元素分成 j 段的最小最大和；cut[i][j]: 最后一段起点
    final dp = List.generate(n + 1, (_) => List<double>.filled(k + 1, double.infinity));
    final cut = List.generate(n + 1, (_) => List<int>.filled(k + 1, 0));
    dp[0][0] = 0;
    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= k && j <= i; j++) {
        for (var p = j - 1; p < i; p++) {
          final cost = dp[p][j - 1] > (prefix[i] - prefix[p]) ? dp[p][j - 1] : (prefix[i] - prefix[p]);
          if (cost <= dp[i][j]) { // 相同代价时偏向让前面的行更满（4 + 3 而不是 3 + 4）
            dp[i][j] = cost;
            cut[i][j] = p;
          }
        }
      }
    }
    final counts = <int>[];
    var i = n, j = k;
    while (j > 0) {
      final p = cut[i][j];
      counts.insert(0, i - p);
      i = p;
      j--;
    }
    return counts;
  }
}
