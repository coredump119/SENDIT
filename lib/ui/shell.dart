import 'package:flutter/material.dart';

import 'app_state.dart';
import 'pages/export_page.dart';
import 'pages/import_page.dart';
import 'pages/result_page.dart';
import 'pages/setup_page.dart';
import 'scope.dart';
import 'theme.dart';
import 'widgets.dart';

const _steps = [
  (Stage.images, '01', '图片'),
  (Stage.chat, '02', '聊天'),
  (Stage.result, '03', '归属'),
  (Stage.export, '04', '拆分'),
];

bool _done(AppState s, Stage st) => switch (st) {
      Stage.images => s.imagesReady,
      Stage.chat => s.chatReady,
      Stage.result => s.resultReady,
      Stage.export => s.exportDone_,
    };

class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final page = switch (s.stage) {
      Stage.images => const SetupPage(),
      Stage.chat => const ImportPage(),
      Stage.result => const ResultPage(),
      Stage.export => const ExportPage(),
    };
    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxWidth < 700;
      // 点空白处收起键盘（按钮和输入框自己会先吃掉点击，不受影响）
      final body = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: page,
      );
      if (compact) {
        return Scaffold(
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: Column(
              children: [
                _TopBar(s: s),
                const HeaderRule(),
                Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 8), child: body)),
                const HeaderRule(),
                _Footer(s: s, compact: true),
              ],
            ),
          ),
        );
      }
      return Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Rail(s: s),
            Container(width: 1, color: Tone.hair),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(40, 34, 40, 18), child: body)),
                  const HeaderRule(),
                  _Footer(s: s, compact: false),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _TopBar extends StatelessWidget {
  final AppState s;
  const _TopBar({required this.s});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 14, 10),
      child: Row(
        children: [
          Text('SENDIT', style: Tone.display.copyWith(fontSize: 22, letterSpacing: 1)),
          if (s.images != null) ...[const SizedBox(width: 10), _NewBatch(s: s, compact: true)],
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: Tone.cream, borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (st, idx, _) in _steps)
                  GestureDetector(
                    onTap: () => s.goTo(st),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: s.stage == st ? Tone.ink : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(idx, style: Tone.num.copyWith(fontSize: 13, color: s.stage == st ? Tone.paper : (_done(s, st) ? Tone.ink : Tone.inkMute))),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  final AppState s;
  const _Rail({required this.s});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 36, 22, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SENDIT', style: Tone.display.copyWith(fontSize: 32, letterSpacing: 1.5)),
            const SizedBox(height: 4),
            const Label('扣号分发'),
            const SizedBox(height: 44),
            for (final (st, idx, name) in _steps)
              _RailItem(idx: idx, name: name, active: s.stage == st, done: _done(s, st), onTap: () => s.goTo(st)),
            const Spacer(),
            if (s.images != null) ...[
              _NewBatch(s: s),
              const SizedBox(height: 18),
            ],
            const Label('Local only'),
            const SizedBox(height: 3),
            Text('不联网 · 不上传', style: Tone.bodySoft),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final String idx;
  final String name;
  final bool active;
  final bool done;
  final VoidCallback onTap;
  const _RailItem({required this.idx, required this.name, required this.active, required this.done, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: active ? Tone.cream : Colors.transparent, borderRadius: BorderRadius.circular(999)),
          child: Row(
            children: [
              Text(idx, style: Tone.num.copyWith(fontSize: 13, color: active ? Tone.ink : Tone.inkMute)),
              const SizedBox(width: 12),
              Text(name, style: Tone.h2.copyWith(fontSize: 19, color: active ? Tone.ink : (done ? Tone.inkSoft : Tone.inkMute))),
              if (done && !active) ...[const Spacer(), const Icon(Icons.check_rounded, size: 14, color: Tone.inkMute)],
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final AppState s;
  final bool compact;
  const _Footer({required this.s, required this.compact});

  @override
  Widget build(BuildContext context) {
    final i = Stage.values.indexOf(s.stage);
    final canNext = switch (s.stage) {
      Stage.images => s.imagesReady,
      Stage.chat => s.resultReady,
      Stage.result => s.resultReady,
      Stage.export => false,
    };
    final hint = switch (s.stage) {
      Stage.images => s.images == null ? '等待图片' : (s.imagesReady ? '${s.maxNumber} 个编号就绪' : '编号有冲突'),
      Stage.chat => s.messages.isEmpty ? '等待粘贴' : (s.resultReady ? '已解析 ${s.messages.length} 条' : '缺少图片编号范围'),
      Stage.result => s.allocation == null ? '' : '${s.allocation!.people.length} 人 · 未认领 ${s.allocation!.unclaimed.length}',
      Stage.export => s.exportSummary != null || s.zipDone ? '完成' : (s.saved.isEmpty ? '' : '已保存 ${s.saved.length} 人'),
    };
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 40, vertical: compact ? 10 : 14),
      child: Row(
        children: [
          SoftButton(label: '上一步', small: compact, onPressed: i == 0 ? null : () => s.goTo(Stage.values[i - 1])),
          const SizedBox(width: 14),
          Expanded(child: Text(hint, style: Tone.bodySoft, overflow: TextOverflow.ellipsis)),
          SoftButton(label: '下一步', primary: true, small: compact, icon: Icons.arrow_forward_rounded, onPressed: canNext ? () => s.goTo(Stage.values[i + 1]) : null),
        ],
      ),
    );
  }
}

class _NewBatch extends StatelessWidget {
  final AppState s;
  final bool compact;
  const _NewBatch({required this.s, this.compact = false});
  @override
  Widget build(BuildContext context) {
    return SoftButton(
      label: '新批次',
      small: true,
      icon: compact ? null : Icons.add_rounded,
      onPressed: () async {
        final ok = await confirmDialog(context, title: '开始新批次', body: '会清空当前的图片、聊天记录、所有轮次和规则。已导出的文件不受影响。', confirm: '清空并新建');
        if (ok) s.newBatch();
      },
    );
  }
}
