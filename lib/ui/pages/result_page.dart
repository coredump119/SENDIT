import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../app_state.dart';
import '../collage_dialog.dart';
import '../widgets.dart';
import '../scope.dart';
import '../theme.dart';

class ResultPage extends StatefulWidget {
  const ResultPage({super.key});
  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  bool _showPeople = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final a = s.allocation;
    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 700;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              index: '03',
              title: '归属',
              compact: compact,
              subtitle: '先到先得，超出限量的自动舍弃并释放。点任意编号可手动改归属。',
              actions: [
                if (compact && a != null)
                  Segmented<bool>(
                    value: _showPeople,
                    onChanged: (v) => setState(() => _showPeople = v),
                    items: const [(false, '编号'), (true, '人')],
                  ),
              ],
            ),
            if (a == null)
              const Expanded(child: EmptyNote('先完成图片与聊天两步'))
            else if (compact)
              Expanded(
                child: _showPeople ? _People(a: a) : _Grid(a: a, compact: true),
              )
            else
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 6, child: _Grid(a: a, compact: false)),
                    const SizedBox(width: 24),
                    Expanded(flex: 5, child: _People(a: a)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Grid extends StatelessWidget {
  final Allocation a;
  final bool compact;
  const _Grid({required this.a, required this.compact});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final assigned = a.owner.values
        .where((v) => v != null && v != Allocation.reservedOwner)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Wrap(
                spacing: compact ? 22 : 34,
                runSpacing: 10,
                children: [
                  InlineStat(label: '已分配', value: '$assigned'),
                  InlineStat(label: '未认领', value: '${a.unclaimed.length}'),
                  InlineStat(label: '自留', value: '${a.reservedNumbers.length}'),
                  InlineStat(
                    label: '人数',
                    value: '${a.people.where((p) => p.got.isNotEmpty).length}',
                  ),
                  if (s.round > 1)
                    InlineStat(label: '前几轮已分', value: '${s.lockedCount}'),
                  if (a.needsReview.isNotEmpty)
                    InlineStat(
                      label: '待确认',
                      value: '${a.needsReview.length}',
                      warn: true,
                    ),
                ],
              ),
            ),
            if (!s.textOnly && a.unclaimed.isNotEmpty)
              SoftButton(
                label: compact ? '拼图' : '剩余拼图',
                small: true,
                icon: Icons.grid_view_rounded,
                onPressed: () => showCollageDialog(context, s),
              ),
          ],
        ),
        if (a.needsReview.isNotEmpty) ...[
          const SizedBox(height: 14),
          _Review(items: a.needsReview),
        ],
        const SizedBox(height: 12),
        const HairRule(),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: compact ? 96 : 104,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: a.maxNumber,
            itemBuilder: (ctx, i) {
              final n = i + 1;
              final id = s.images?.byNumber[n];
              final lockedRound = s.locked[n]?.$2;
              return _Cell(
                n: n,
                owner: a.owner[n],
                provider: id == null ? null : s.thumb(id, 220),
                overridden: s.manualOverrides.containsKey(n),
                lockedRound: lockedRound,
                textOnly: s.textOnly,
                onTap: lockedRound != null
                    ? null
                    : (pos) => _menu(ctx, s, a, n, pos),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _menu(
    BuildContext ctx,
    AppState s,
    Allocation a,
    int n,
    Offset pos,
  ) async {
    final overlay = Overlay.of(ctx).context.findRenderObject() as RenderBox;
    final choice = await showMenu<String>(
      context: ctx,
      position: RelativeRect.fromRect(
        pos & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(enabled: false, height: 28, child: Label('No. $n')),
        const PopupMenuItem(
          value: '__release',
          height: 36,
          child: Text('释放（未认领）'),
        ),
        const PopupMenuItem(
          value: '__reserve',
          height: 36,
          child: Text('设为自留'),
        ),
        if (s.manualOverrides.containsKey(n))
          const PopupMenuItem(
            value: '__clear',
            height: 36,
            child: Text('撤销手动指定'),
          ),
        const PopupMenuDivider(),
        for (final p in a.people)
          PopupMenuItem(value: p.name, height: 36, child: Text('→ ${p.name}')),
      ],
    );
    if (choice == null) return;
    switch (choice) {
      case '__release':
        s.override(n, null);
      case '__reserve':
        s.override(n, Allocation.reservedOwner);
      case '__clear':
        s.override(n, null, clear: true);
      default:
        s.override(n, choice);
    }
  }
}

class _Cell extends StatelessWidget {
  final int n;
  final String? owner;
  final ImageProvider? provider;
  final bool overridden;
  final int? lockedRound;
  final bool textOnly;
  final void Function(Offset)? onTap;
  const _Cell({
    required this.n,
    required this.owner,
    required this.provider,
    required this.overridden,
    required this.onTap,
    this.lockedRound,
    this.textOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final reserved = owner == Allocation.reservedOwner;
    final lockedCell = lockedRound != null;
    final taken = owner != null && !reserved;
    final band = reserved
        ? Tone.moss
        : (lockedCell ? Tone.inkMute : (taken ? Tone.ink : Tone.paper));
    final bandFg = owner == null ? Tone.inkSoft : Tone.paper;
    const circled = ['①', '②', '③', '④', '⑤', '⑥', '⑦', '⑧', '⑨'];
    return MouseRegion(
      cursor: onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTapUp: onTap == null ? null : (d) => onTap!(d.globalPosition),
        child: Container(
          decoration: BoxDecoration(
            color: Tone.paper,
            borderRadius: BorderRadius.circular(Tone.rSmall + 1),
            border: Border.all(
              color: owner == null ? Tone.hairSoft : Tone.hair,
              width: 1,
            ),
            boxShadow: owner == null ? null : Tone.tinyShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (provider != null)
                      Opacity(
                        opacity: owner == null ? 0.35 : 1,
                        child: Image(
                          image: provider!,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.low,
                        ),
                      )
                    else if (!textOnly)
                      Center(child: Text('缺图', style: Tone.monoSmall))
                    else
                      Center(
                        child: Text(
                          '$n',
                          style: Tone.numeral.copyWith(
                            fontSize: 26,
                            color: owner == null ? Tone.inkMute : Tone.inkSoft,
                          ),
                        ),
                      ),
                    if (overridden)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Tone.ink,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: const Text(
                            '手',
                            style: TextStyle(
                              fontSize: 9,
                              color: Tone.paper,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                color: band,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                child: Row(
                  children: [
                    Text(
                      '$n',
                      style: Tone.num.copyWith(color: bandFg, fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    if (lockedCell) ...[
                      Text(
                        lockedRound! <= circled.length
                            ? circled[lockedRound! - 1]
                            : '$lockedRound',
                        style: TextStyle(
                          fontSize: 11,
                          color: bandFg,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 3),
                    ],
                    Expanded(
                      child: Text(
                        reserved ? '自留' : (owner ?? ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: bandFg,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Review extends StatelessWidget {
  final List<ParsedMessage> items;
  const _Review({required this.items});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Panel(
      fill: Tone.cream,
      border: Colors.transparent,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Label('需人工确认 · 含数字但夹杂文字'),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 150),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final m in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: Tone.body,
                              children: [
                                TextSpan(
                                  text: '${m.raw.sender}：',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(text: m.raw.text),
                                TextSpan(
                                  text: '   → ${m.claims.join(', ')}',
                                  style: Tone.num.copyWith(
                                    fontSize: 13,
                                    color: Tone.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SoftButton(
                          label: '采纳',
                          small: true,
                          primary: true,
                          onPressed: () => s.approve(m.raw.order),
                        ),
                        const SizedBox(width: 6),
                        SoftButton(
                          label: '忽略',
                          small: true,
                          onPressed: () => s.ignore(m.raw.order),
                        ),
                      ],
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

class _People extends StatelessWidget {
  final Allocation a;
  const _People({required this.a});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('按首次扣号顺序', style: Tone.bodySoft),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              for (final p in a.people)
                _PersonCard(
                  p: p,
                  limit: s.personLimits[p.name],
                  defaultLimit: s.defaultLimit,
                ),
              for (final name in s.excluded)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: Tone.hairSoft,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: Tone.h3.copyWith(color: Tone.inkMute),
                          ),
                        ),
                        const Tag('已排除', color: Tone.moss),
                        const SizedBox(width: 8),
                        SoftButton(
                          label: '恢复',
                          small: true,
                          onPressed: () => s.toggleExcluded(name),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PersonCard extends StatelessWidget {
  final PersonResult p;
  final int? limit;
  final int? defaultLimit;
  const _PersonCard({
    required this.p,
    required this.limit,
    required this.defaultLimit,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        raised: true,
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.name,
                    style: Tone.h2.copyWith(fontSize: 20),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${p.got.length}',
                  style: Tone.numeral.copyWith(fontSize: 22),
                ),
                const SizedBox(width: 4),
                Text('张', style: Tone.bodySoft),
                const SizedBox(width: 12),
                Text('限', style: Tone.bodySoft),
                const SizedBox(width: 4),
                NumField(
                  value: limit,
                  hint: defaultLimit?.toString() ?? '∞',
                  width: 48,
                  onChanged: (v) => s.setPersonLimit(p.name, v),
                ),
                const SizedBox(width: 8),
                SoftButton(
                  label: '排除',
                  small: true,
                  onPressed: () => s.toggleExcluded(p.name),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const HairRule(),
            const SizedBox(height: 8),
            _line('得到', p.got.isEmpty ? '—' : Report.compress(p.got)),
            if (p.lostTo.isNotEmpty)
              _line(
                '被先扣',
                p.lostTo
                    .map(
                      (l) =>
                          '${l.number}(${l.to == Allocation.reservedOwner ? '自留' : l.to})',
                    )
                    .join('  '),
              ),
            if (p.droppedByLimit.isNotEmpty)
              _line('超限', Report.compress(p.droppedByLimit)),
          ],
        ),
      ),
    );
  }

  Widget _line(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Label(k, color: Tone.inkMute),
            ),
          ),
          Expanded(child: Text(v, style: Tone.num.copyWith(fontSize: 14))),
        ],
      ),
    );
  }
}
