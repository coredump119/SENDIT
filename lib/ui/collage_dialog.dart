import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../platform/ops.dart' as ops;
import 'app_state.dart';
import 'collage.dart';
import 'theme.dart';
import 'widgets.dart';

/// 生成"剩余图拼图"并预览 / 保存
Future<void> showCollageDialog(BuildContext context, AppState s) async {
  final a = s.allocation;
  if (a == null || s.images == null) return;
  final numbers = a.unclaimed;
  if (numbers.isEmpty) return;
  final title = s.round >= 1 ? '第 ${s.round + 1} 轮可扣' : '剩余可扣';
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CollageDialog(s: s, numbers: numbers, title: title),
  );
}

class _CollageDialog extends StatefulWidget {
  final AppState s;
  final List<int> numbers;
  final String title;
  const _CollageDialog({required this.s, required this.numbers, required this.title});
  @override
  State<_CollageDialog> createState() => _CollageDialogState();
}

class _CollageDialogState extends State<_CollageDialog> {
  List<Uint8List>? _pages;
  CollageSource? _src;
  int _done = 0;
  String? _error;
  bool _saving = false;
  String? _savedNote;
  int _renderSeq = 0;

  @override
  void initState() {
    super.initState();
    _prepareAndRender();
  }

  Future<void> _prepareAndRender() async {
    try {
      _src = await const CollageBuilder().prepare(
        images: widget.s.images!,
        numbers: widget.numbers,
        onProgress: (d, _) {
          if (mounted) setState(() => _done = d);
        },
      );
      await _render();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// 改设置只重排 + 重画，不重新读图；连续点击时只保留最后一次
  Future<void> _render() async {
    final src = _src;
    if (src == null) return;
    final seq = ++_renderSeq;
    setState(() {
      _pages = null;
      _savedNote = null;
    });
    try {
      final s = widget.s;
      final pages = await CollageBuilder(layout: s.collageLayout).render(src, title: widget.title, watermark: s.collageWatermark);
      if (mounted && seq == _renderSeq) setState(() => _pages = pages);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Widget _settings() {
    final s = widget.s;
    final ready = _src != null;
    return Wrap(
      spacing: 14,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Field(
          label: '每页',
          child: Segmented<int>(
            value: s.collagePerPage,
            onChanged: ready ? (v) { s.setCollage(perPage: v); _render(); } : (_) {},
            items: const [(4, '4'), (6, '6'), (8, '8'), (12, '12')],
          ),
        ),
        Field(
          label: '每行',
          child: Segmented<int>(
            value: s.collagePortraitsPerRow,
            onChanged: ready ? (v) { s.setCollage(portraitsPerRow: v); _render(); } : (_) {},
            items: const [(3, '宽松'), (4, '标准'), (5, '紧凑')],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Check(value: s.collageWatermark, onChanged: ready ? (v) { s.setCollage(watermark: v); _render(); } : (_) {}),
            const SizedBox(width: 8),
            Text('防盗纹', style: Tone.body),
          ],
        ),
      ],
    );
  }

  Future<void> _save() async {
    final s = widget.s;
    setState(() => _saving = true);
    try {
      String? dir;
      if (AppState.isDesktop) {
        s.ensureOutputDir();
        if (s.outputDir == null) await s.pickOutputDir();
        dir = s.outputDir;
        if (dir == null) {
          setState(() => _saving = false);
          return;
        }
      }
      final stamp = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      final base = '拼图_第${s.round + 1}轮_${two(stamp.month)}${two(stamp.day)}${two(stamp.hour)}${two(stamp.minute)}';
      String? lastPath;
      for (var i = 0; i < _pages!.length; i++) {
        lastPath = await ops.saveImageBytes(_pages![i], _pages!.length > 1 ? '${base}_p${i + 1}.jpg' : '$base.jpg', dir: dir);
      }
      setState(() => _savedNote = AppState.isDesktop ? '已保存到 $dir' : (AppState.isWeb ? '已开始下载' : '已保存到相册'));
      if (lastPath != null && AppState.isDesktop) await ops.revealFolder(dir!);
    } catch (e) {
      setState(() => _error = '保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    return Dialog(
      backgroundColor: Tone.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tone.rPanel)),
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('${widget.title} · 拼图', style: Tone.h2)),
                  if (pages != null) Text('${widget.numbers.length} 张 · ${pages.length} 页', style: Tone.bodySoft),
                ],
              ),
              const SizedBox(height: 10),
              _settings(),
              const SizedBox(height: 12),
              Flexible(
                child: _error != null
                    ? Text(_error!, style: Tone.body.copyWith(color: Tone.moss))
                    : pages == null
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                                const SizedBox(height: 12),
                                Text(_src == null ? '正在读取 $_done / ${widget.numbers.length}…' : '正在排版…', style: Tone.bodySoft),
                              ],
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: pages.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => ClipRRect(
                              borderRadius: BorderRadius.circular(Tone.rSmall),
                              child: Image.memory(pages[i], fit: BoxFit.contain, gaplessPlayback: true),
                            ),
                          ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (_savedNote != null) Expanded(child: Text(_savedNote!, style: Tone.bodySoft)) else const Spacer(),
                  SoftButton(label: '关闭', small: true, onPressed: () => Navigator.of(context).pop()),
                  const SizedBox(width: 8),
                  SoftButton(
                    label: _saving ? '保存中…' : (AppState.isWeb ? '下载' : (AppState.isMobile ? '保存到相册' : '保存')),
                    small: true,
                    primary: true,
                    icon: Icons.arrow_downward_rounded,
                    onPressed: pages == null || _saving ? null : _save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
