import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../app_state.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets.dart';
import 'gallery_picker_page.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});
  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  bool _dragging = false;
  final _maxCtrl = TextEditingController();

  @override
  void dispose() {
    _maxCtrl.dispose();
    super.dispose();
  }

  /// 无图模式入口：编号总数 + 开始
  Widget _textOnlyEntry(AppState s, {bool compact = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('不需要图片？只用聊天记录算归属', style: Tone.bodySoft),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('编号 1 到', style: Tone.body),
            const SizedBox(width: 8),
            SizedBox(
              width: 72,
              child: TextField(
                controller: _maxCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: Tone.num,
                decoration: const InputDecoration(hintText: '40'),
                onSubmitted: (_) => s.setManualMax(int.tryParse(_maxCtrl.text.trim())),
              ),
            ),
            const SizedBox(width: 10),
            SoftButton(label: '无图开始', small: true, onPressed: () => s.setManualMax(int.tryParse(_maxCtrl.text.trim()))),
          ],
        ),
      ],
    );
  }

  /// 安卓：应用内相册（系统选择器在 Android ≤12 / 无 GMS 机型上会变成文件浏览器）；其他平台走系统选择
  Future<void> _pick(AppState s) async {
    if (AppState.isAndroid) {
      final picked = await GalleryPickerPage.open(context);
      if (picked != null && picked.isNotEmpty) await s.importPicked(picked);
    } else {
      await s.pickImages();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final ix = s.images;
    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxWidth < 700;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            index: '01',
            title: s.textOnly ? '编号' : '图片',
            compact: compact,
            subtitle: AppState.isMobile
                ? '从相册多选，按选择顺序自动编号；长按缩略图拖动可调整顺序。'
                : AppState.isWeb
                    ? '拖入或多选一批图片。编号可以从文件名读取，也可以按顺序自动编号，再拖动缩略图调整。'
                    : '拖入整个文件夹，编号从文件名读取；或改成按顺序自动编号，再拖动缩略图调整。',
            actions: [
              if (ix != null && AppState.canPickFolder) SoftButton(label: '换文件夹', small: compact, onPressed: s.pickFolder),
              if (ix != null) SoftButton(label: AppState.isMobile ? '重新选择' : '选图片', small: compact, onPressed: () => _pick(s)),
            ],
          ),
          Expanded(
            child: DropTarget(
              onDragEntered: (_) => setState(() => _dragging = true),
              onDragExited: (_) => setState(() => _dragging = false),
              onDragDone: (d) {
                setState(() => _dragging = false);
                s.handleDrop(d.files);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (s.importing) ...[_ImportBar(s: s), const SizedBox(height: 12)],
                  Expanded(child: s.textOnly ? _textOnlyLoaded(s, compact) : (ix == null ? _empty(s, compact) : _loaded(s, ix, compact))),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _empty(AppState s, bool compact) {
    final mobile = AppState.isMobile;
    final title = mobile ? '选择要分发的图片' : (_dragging ? '松手' : (AppState.canPickFolder ? '把文件夹拖到这里' : '把图片拖到这里'));
    final sub = mobile
        ? '按你选择的顺序编号，之后可以拖动调整'
        : AppState.canPickFolder
            ? '也可以直接拖一批图片，按拖入顺序编号'
            : '一次选中整批图片；文件名带编号的会自动识别';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: _dragging ? Tone.cream : Tone.paper,
        borderRadius: BorderRadius.circular(Tone.rPanel),
        border: Border.all(color: _dragging ? Tone.inkSoft : Tone.hair, width: 1),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: Tone.display.copyWith(fontSize: compact ? 30 : 40)),
            const SizedBox(height: 6),
            Text(sub, style: Tone.bodySoft, textAlign: TextAlign.center),
            const SizedBox(height: 22),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                if (AppState.canPickFolder) SoftButton(label: '选择文件夹', primary: true, onPressed: s.pickFolder),
                SoftButton(label: mobile ? '从相册选择' : '选择图片', primary: !AppState.canPickFolder, onPressed: () => _pick(s)),
              ],
            ),
            const SizedBox(height: 28),
            const SizedBox(width: 120, child: HairRule()),
            const SizedBox(height: 18),
            _textOnlyEntry(s, compact: compact),
          ],
        ),
      ),
    );
  }

  /// 无图模式已开启
  Widget _textOnlyLoaded(AppState s, bool compact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: compact ? 22 : 34,
          runSpacing: 12,
          children: [
            InlineStat(label: '模式', value: '无图'),
            InlineStat(label: '编号范围', value: '1–${s.manualMax}'),
          ],
        ),
        const SizedBox(height: 12),
        const HairRule(),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('只用聊天记录算归属', style: Tone.h3),
              const SizedBox(height: 6),
              Text('不选图片，编号 1 到 ${s.manualMax}。后面的解析、归属、第二轮都一样，最后一页会按人列出号码，直接复制发群。', style: Tone.bodySoft),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('改总数', style: Tone.body),
                  SizedBox(
                    width: 72,
                    child: TextField(
                      controller: _maxCtrl..text = '${s.manualMax}',
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: Tone.num,
                      onSubmitted: (_) => s.setManualMax(int.tryParse(_maxCtrl.text.trim())),
                    ),
                  ),
                  SoftButton(label: '应用', small: true, onPressed: () => s.setManualMax(int.tryParse(_maxCtrl.text.trim()))),
                  SoftButton(label: '改用图片', small: true, onPressed: () => s.setManualMax(null)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _loaded(AppState s, ImageIndex ix, bool compact) {
    final seq = s.numberRule == NumberRule.sequential;
    final dupCount = ix.duplicates.length;
    final stats = Wrap(
      spacing: compact ? 22 : 34,
      runSpacing: 12,
      children: [
        InlineStat(label: '图片', value: '${ix.images.length}'),
        InlineStat(label: '最大编号', value: '${ix.maxNumber}'),
        InlineStat(label: '缺号', value: ix.missing.isEmpty ? '无' : Report.compress(ix.missing), warn: ix.missing.isNotEmpty),
        InlineStat(label: '重复', value: dupCount == 0 ? '无' : Report.compress(ix.duplicates.keys), warn: dupCount > 0),
        if (ix.unnumbered.isNotEmpty) InlineStat(label: '无编号', value: '${ix.unnumbered.length}', warn: true),
      ],
    );
    final controls = Wrap(
      spacing: 14,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        Field(
          label: '编号方式',
          child: Segmented<NumberRule>(
            value: s.numberRule,
            onChanged: s.setNumberRule,
            items: const [(NumberRule.firstNumber, '文件名·首段'), (NumberRule.lastNumber, '文件名·末段'), (NumberRule.sequential, '按顺序')],
          ),
        ),
        if (seq && s.imageDir != null)
          Field(
            label: '排序',
            child: Segmented<SortMode>(value: s.sortMode, onChanged: s.setSortMode, items: const [(SortMode.name, '文件名'), (SortMode.mtime, '修改时间')]),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s.imageDir != null) ...[Text(s.imageDir!, style: Tone.monoSmall, overflow: TextOverflow.ellipsis), const SizedBox(height: 12)],
        if (compact) ...[stats, const SizedBox(height: 14), controls] else Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: stats), controls]),
        const SizedBox(height: 10),
        if (dupCount > 0)
          Text('有重复编号，拆分前必须处理：改文件名、切换编号方式，或改为按顺序编号。', style: Tone.body.copyWith(color: Tone.moss))
        else if (seq)
          Text(compact ? '长按缩略图拖到目标位置即可调整顺序。' : '拖动缩略图到目标位置即可调整顺序。', style: Tone.bodySoft),
        const SizedBox(height: 12),
        const HairRule(),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: compact ? 110 : 128, mainAxisSpacing: 10, crossAxisSpacing: 10),
            itemCount: ix.images.length,
            itemBuilder: (_, i) {
              final img = ix.images[i];
              final tile = _Thumb(img: img, dup: ix.duplicates.containsKey(img.number), provider: s.thumb(img.path, 260));
              if (!seq) return tile;
              return _DragTile(id: img.path, compact: compact, onDrop: (from) => s.moveImage(from, i), child: tile);
            },
          ),
        ),
      ],
    );
  }
}

class _DragTile extends StatelessWidget {
  final String id;
  final bool compact;
  final Widget child;
  final ValueChanged<String> onDrop;
  const _DragTile({required this.id, required this.compact, required this.child, required this.onDrop});

  @override
  Widget build(BuildContext context) {
    final feedback = Opacity(opacity: 0.9, child: SizedBox(width: 96, height: 96, child: child));
    final draggable = compact
        ? LongPressDraggable<String>(data: id, feedback: feedback, childWhenDragging: Opacity(opacity: 0.25, child: child), child: child)
        : Draggable<String>(data: id, feedback: feedback, childWhenDragging: Opacity(opacity: 0.25, child: child), child: child);
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != id,
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (_, cand, _) => AnimatedScale(scale: cand.isNotEmpty ? 0.92 : 1, duration: const Duration(milliseconds: 120), child: draggable),
    );
  }
}

class _Thumb extends StatelessWidget {
  final IndexedImage img;
  final bool dup;
  final ImageProvider provider;
  const _Thumb({required this.img, required this.dup, required this.provider});

  @override
  Widget build(BuildContext context) {
    final bad = dup || img.number == null;
    return Tooltip(
      message: img.name,
      child: Container(
        decoration: BoxDecoration(
          color: Tone.paper,
          borderRadius: BorderRadius.circular(Tone.rSmall + 1),
          border: Border.all(color: bad ? Tone.moss : Tone.hair, width: bad ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(image: provider, fit: BoxFit.cover, filterQuality: FilterQuality.low),
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: bad ? Tone.moss : Tone.paper.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(999)),
                child: Text(
                  img.number == null ? '无编号' : (dup ? '${img.number} 重复' : '${img.number}'),
                  style: Tone.num.copyWith(fontSize: 12.5, color: bad ? Tone.paper : Tone.ink),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 导入中的提示条：纸色 / 细线风格。等待系统相册时用每 500ms 变一次的省略号表示"活着"，
/// 不用高帧率动画（之前的转圈会抢主线程，拖慢 iOS 导出）。
class _ImportBar extends StatefulWidget {
  final AppState s;
  const _ImportBar({required this.s});
  @override
  State<_ImportBar> createState() => _ImportBarState();
}

class _ImportBarState extends State<_ImportBar> {
  Timer? _timer;
  int _dots = 1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _dots = _dots % 3 + 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final hasTotal = s.importTotal > 0;
    final note = hasTotal ? s.importNote : '${s.importNote}${'·' * _dots}';
    return Panel(
      fill: Tone.cream,
      border: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Label('导入中'),
              const SizedBox(width: 12),
              Expanded(child: Text(note, style: Tone.body)),
              if (hasTotal) Text('${s.importDone} / ${s.importTotal}', style: Tone.num.copyWith(color: Tone.inkSoft)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: hasTotal ? s.importDone / s.importTotal : 0,
              minHeight: 4,
              backgroundColor: Tone.hairSoft,
              color: Tone.ink,
            ),
          ),
        ],
      ),
    );
  }
}
