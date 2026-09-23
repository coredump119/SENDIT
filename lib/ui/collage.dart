import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../core/core.dart';
import '../platform/ops.dart' as ops;
import 'theme.dart';

/// 读好的图：尺寸 + 原始字节，改设置重排时复用
class CollageSource {
  final List<CollageItem> items;
  final Map<int, Uint8List> bytesOf;
  const CollageSource(this.items, this.bytesOf);
}

/// 把一组编号图片渲染成带编号的拼图（等高行排版），输出 JPEG 页。
class CollageBuilder {
  final CollageLayout layout;
  const CollageBuilder({this.layout = const CollageLayout()});

  static const _decodeLongEdge = 1000;

  /// 一次性读取 + 量尺寸；之后改排版设置只需 [render]，不用再读图
  Future<CollageSource> prepare({
    required ImageIndex images,
    required List<int> numbers,
    void Function(int done, int total)? onProgress,
  }) async {
    final items = <CollageItem>[];
    final bytesOf = <int, Uint8List>{};
    var done = 0;
    for (final n in numbers) {
      final id = images.byNumber[n];
      if (id == null) continue;
      final bytes = await ops.readBytes(id);
      final size = await _measure(bytes);
      items.add(CollageItem(number: n, width: size.$1.toDouble(), height: size.$2.toDouble()));
      bytesOf[n] = bytes;
      onProgress?.call(++done, numbers.length);
    }
    return CollageSource(items, bytesOf);
  }

  /// 按当前 [layout] 排版并逐页渲染（长边 ≤ 1000，画完即释放）
  Future<List<Uint8List>> render(CollageSource src, {required String title, bool watermark = true}) async {
    final pages = layout.paginate(src.items);
    final out = <Uint8List>[];
    for (var i = 0; i < pages.length; i++) {
      final decoded = <int, ui.Image>{};
      for (final pl in pages[i].items) {
        decoded[pl.number] = await _decode(src.bytesOf[pl.number]!);
      }
      out.add(await _renderPage(pages[i], decoded, title: title, page: i + 1, pageCount: pages.length, total: src.items.length, watermark: watermark));
      for (final im in decoded.values) {
        im.dispose();
      }
    }
    return out;
  }

  /// 兼容旧调用：prepare + render
  Future<List<Uint8List>> build({
    required ImageIndex images,
    required List<int> numbers,
    required String title,
    bool watermark = true,
    void Function(int done, int total)? onProgress,
  }) async {
    final src = await prepare(images: images, numbers: numbers, onProgress: onProgress);
    return render(src, title: title, watermark: watermark);
  }

  Future<(int, int)> _measure(Uint8List bytes) async {
    var w = 0, h = 0;
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final codec = await ui.instantiateImageCodecWithSize(
      buffer,
      getTargetSize: (iw, ih) {
        w = iw;
        h = ih;
        final k = 8 / (iw > ih ? iw : ih);
        return ui.TargetImageSize(width: (iw * k).ceil().clamp(1, iw), height: (ih * k).ceil().clamp(1, ih));
      },
    );
    final frame = await codec.getNextFrame();
    frame.image.dispose();
    codec.dispose();
    return (w, h);
  }

  Future<ui.Image> _decode(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final codec = await ui.instantiateImageCodecWithSize(
      buffer,
      getTargetSize: (w, h) {
        final long = w > h ? w : h;
        if (long <= _decodeLongEdge) return ui.TargetImageSize(width: w, height: h);
        final k = _decodeLongEdge / long;
        return ui.TargetImageSize(width: (w * k).round(), height: (h * k).round());
      },
    );
    final frame = await codec.getNextFrame();
    codec.dispose(); // instantiateImageCodecWithSize 已接管 buffer，不能再手动 dispose
    return frame.image;
  }

  Future<Uint8List> _renderPage(CollagePage pg, Map<int, ui.Image> decoded,
      {required String title, required int page, required int pageCount, required int total, bool watermark = true}) async {
    final tile = watermark ? await _hatchTile() : null;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final w = pg.width, h = pg.height;
    c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = Tone.bg);

    // 页眉
    _text(c, title, Offset(layout.margin, layout.margin + 6), size: 56, color: Tone.ink, weight: FontWeight.w500);
    _text(c, 'SENDIT', Offset(layout.margin, layout.margin + 78), size: 22, color: Tone.inkMute, letterSpacing: 4);
    final pageLabel = pageCount > 1 ? '共 $total 张 · 第 $page / $pageCount 页' : '共 $total 张';
    _text(c, pageLabel, Offset(w - layout.margin, layout.margin + 30), size: 26, color: Tone.inkSoft, alignRight: true);
    c.drawRect(Rect.fromLTWH(layout.margin, layout.margin + layout.headerHeight - 22, w - layout.margin * 2, 2), Paint()..color = Tone.hair);

    for (final pl in pg.items) {
      final im = decoded[pl.number]!;
      final dest = Rect.fromLTWH(pl.x, pl.y, pl.w, pl.h);
      final rr = RRect.fromRectAndRadius(dest, const Radius.circular(18));
      c.save();
      c.clipRRect(rr);
      c.drawRect(dest, Paint()..color = Tone.paper);
      // contain：比例被夹住时居中留白
      final r = im.width / im.height;
      var fw = pl.w, fh = pl.w / r;
      if (fh > pl.h) {
        fh = pl.h;
        fw = pl.h * r;
      }
      final fit = Rect.fromLTWH(pl.x + (pl.w - fw) / 2, pl.y + (pl.h - fh) / 2, fw, fh);
      c.drawImageRect(im, Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()), fit, Paint()..filterQuality = FilterQuality.high);
      if (tile != null) _hatch(c, fit, tile);
      c.restore();
      c.drawRRect(rr, Paint()..color = Tone.hair..style = PaintingStyle.stroke..strokeWidth = 2);

      // 编号角标：左下角胶囊
      final badge = _badgeSize(pl);
      final tp = _painter('${pl.number}', size: badge * 0.62, color: Tone.ink, weight: FontWeight.w500);
      final bw = tp.width + badge * 0.7, bh = badge;
      final bx = pl.x + badge * 0.35, by = pl.y + pl.h - bh - badge * 0.35;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw, bh), Radius.circular(bh)), Paint()..color = Tone.paper.withValues(alpha: 0.94));
      tp.paint(c, Offset(bx + badge * 0.35, by + (bh - tp.height) / 2));
    }

    final picture = rec.endRecording();
    final image = await picture.toImage(w.round(), h.round());
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    final im = img.Image.fromBytes(width: w.round(), height: h.round(), bytes: raw!.buffer, numChannels: 4, order: img.ChannelOrder.rgba);
    return Uint8List.fromList(img.encodeJpg(im, quality: 88));
  }

  /// 细密斜纹底纹（柔光叠加）：无缝瓦片，45°、周期 6px、明暗交替线
  static ui.Image? _tile;

  static Future<ui.Image> _hatchTile() async {
    if (_tile != null) return _tile!;
    const size = 96.0; // 6 的倍数，保证 45° 线无缝平铺
    const period = 6.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(const Rect.fromLTWH(0, 0, size, size), Paint()..color = const Color(0xFF808080)); // 中灰 = 柔光下不变
    final light = Paint()
      ..color = const Color(0xFFE6E6E6)
      ..strokeWidth = 1.6
      ..isAntiAlias = true;
    final dark = Paint()
      ..color = const Color(0xFF2E2E2E)
      ..strokeWidth = 1.2
      ..isAntiAlias = true;
    // x - y = k·period 的 45° 线；每条亮线旁半个周期放一条暗线
    for (var k = -size; k <= size * 2; k += period) {
      c.drawLine(Offset(k, 0), Offset(k - size, size), light);
      c.drawLine(Offset(k + period / 2, 0), Offset(k + period / 2 - size, size), dark);
    }
    _tile = await rec.endRecording().toImage(size.toInt(), size.toInt());
    return _tile!;
  }

  void _hatch(Canvas c, Rect r, ui.Image tile) {
    final paint = Paint()
      ..shader = ImageShader(tile, TileMode.repeated, TileMode.repeated, Matrix4.identity().storage)
      ..blendMode = BlendMode.softLight;
    c.drawRect(r, paint);
  }

  double _badgeSize(Placement pl) => (pl.h * 0.11).clamp(44.0, 72.0);

  TextPainter _painter(String s, {required double size, required Color color, FontWeight weight = FontWeight.w400, double letterSpacing = 0}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontFamily: Tone.serif, fontFamilyFallback: const ['NotoSansSC'], fontSize: size, color: color, fontWeight: weight, letterSpacing: letterSpacing, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp;
  }

  void _text(Canvas c, String s, Offset at, {required double size, required Color color, FontWeight weight = FontWeight.w400, double letterSpacing = 0, bool alignRight = false}) {
    final tp = _painter(s, size: size, color: color, weight: weight, letterSpacing: letterSpacing);
    tp.paint(c, alignRight ? Offset(at.dx - tp.width, at.dy) : at);
  }
}
