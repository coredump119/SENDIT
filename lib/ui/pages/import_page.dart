import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../platform/clipboard_all.dart';
import '../app_state.dart';
import '../widgets.dart';
import '../scope.dart';
import '../theme.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({super.key});
  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  late final TextEditingController _text;
  late final TextEditingController _reserved;
  late final TextEditingController _start;
  final FocusNode _focus = FocusNode();
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_typing != _focus.hasFocus) setState(() => _typing = _focus.hasFocus);
    });
    final s = AppScope.read(context);
    _text = TextEditingController(text: s.chatText);
    _reserved = TextEditingController(text: Report.compress(s.reserved, sep: ','));
    _start = TextEditingController(text: s.startTimeText);
  }

  @override
  void dispose() {
    _focus.dispose();
    _text.dispose();
    _reserved.dispose();
    _start.dispose();
    super.dispose();
  }

  void _dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  Future<void> _confirmCancelRound(AppState s) async {
    final ok = await confirmDialog(context, title: '取消第 ${s.round} 轮', body: '会丢弃本轮粘贴的记录，回到第 ${s.round - 1} 轮的结果。');
    if (ok) {
      s.cancelRound();
      _text.text = s.chatText;
      _start.text = s.startTimeText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxWidth < 700;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            index: '02',
            title: s.round > 1 ? '聊天 · 第 ${s.round} 轮' : '聊天',
            compact: compact,
            subtitle: s.round > 1
                ? '前 ${s.round - 1} 轮已锁定 ${s.lockedCount} 张，编号不变。粘贴第 ${s.round} 轮的群聊记录，只会分配剩下的号。'
                : '微信里多选消息 → 复制，回来点"粘贴并解析"（微信复制的是多条，用这个按钮才能全部读到）。点任意一条可设为起点；设了开始时间，之前的消息会排到最后处理。',
            actions: [
              if (s.canCancelRound) SoftButton(label: '取消第 ${s.round} 轮', small: true, onPressed: () => _confirmCancelRound(s)),
            ],
          ),
          if (s.maxNumber == 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Panel(
                fill: Tone.cream,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Text('还没导入图片，先完成第 01 步，编号范围才能确定。', style: Tone.body),
              ),
            ),
          Expanded(
            child: compact
                ? ListView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      SizedBox(height: 210, child: _editor(s)),
                      const SizedBox(height: 12),
                      _rules(s, compact),
                      const SizedBox(height: 12),
                      SizedBox(height: 460, child: _list(s)),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _editor(s)),
                            const SizedBox(height: 16),
                            _rules(s, compact),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(flex: 6, child: _list(s)),
                    ],
                  ),
          ),
        ],
      );
    });
  }

  Widget _editor(AppState s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Label('粘贴聊天'),
            const Spacer(),
            if (_typing) ...[
              SoftButton(label: '收起键盘', small: true, icon: Icons.keyboard_hide_rounded, onPressed: _dismissKeyboard),
              const SizedBox(width: 6),
            ],
            SoftButton(
              label: '粘贴并解析',
              primary: true,
              small: true,
              icon: Icons.content_paste_rounded,
              onPressed: () async {
                _dismissKeyboard();
                final t = await ClipboardAll.readAll();
                if (t.trim().isEmpty) return;
                _text.text = t;
                s.setChatText(t);
                s.parseChat();
              },
            ),
            const SizedBox(width: 6),
            SoftButton(
              label: '解析',
              small: true,
              onPressed: () {
                _dismissKeyboard();
                s.setChatText(_text.text);
                s.parseChat();
              },
            ),
          ],
        ),

        const SizedBox(height: 8),
        Expanded(
          child: Framed(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: TextField(
                controller: _text,
                focusNode: _focus,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: Tone.monoText,
                decoration: const InputDecoration.collapsed(hintText: '麋鹿\n2026/08/30 21:59\n16 4\n\n青柠\n2026/08/30 22:00\n9/12', filled: false),
                onChanged: s.setChatText,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _rules(AppState s, bool compact) {
    return Wrap(
      spacing: 16,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        Field(label: '每人限量', child: NumField(value: s.defaultLimit, onChanged: s.setDefaultLimit)),
        Field(
          label: '开始时间',
          child: SizedBox(
            width: 84,
            child: TextField(
              controller: _start,
              style: Tone.monoText,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(hintText: '22:00'),
              onChanged: s.setStartTimeText,
            ),
          ),
        ),
        Field(
          label: '作者自留',
          child: SizedBox(
            width: 120,
            child: TextField(
              controller: _reserved,
              style: Tone.monoText,
              decoration: const InputDecoration(hintText: '1,2,5-8'),
              onChanged: s.setReservedText,
            ),
          ),
        ),
        Field(
          label: '作者昵称',
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Tone.paper, borderRadius: BorderRadius.circular(Tone.rSmall), border: Border.all(color: Tone.hair, width: 1)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: s.authorName,
                hint: Text('不排除', style: Tone.bodySoft),
                style: Tone.body,
                dropdownColor: Tone.paper,
                borderRadius: BorderRadius.circular(12),
                isDense: true,
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('不排除')),
                  for (final n in s.senders) DropdownMenuItem<String?>(value: n, child: Text(n)),
                ],
                onChanged: s.setAuthor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _list(AppState s) {
    if (s.messages.isEmpty) return const EmptyNote('解析后消息在这里');
    final parsedByOrder = {for (final pm in s.parsed) pm.raw.order: pm};
    final okCount = s.parsed.where((m) => m.status == ParseStatus.ok).length;
    final ambCount = s.parsed.where((m) => m.status == ParseStatus.ambiguous).length;
    final earlyCount = s.messages.where(s.isEarly).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('${s.messages.length} 条 · ${s.senders.length} 人', style: Tone.bodySoft),
            const Spacer(),
            if (s.parsed.isNotEmpty) ...[
              Tag('$okCount 有效', filled: true),
              if (ambCount > 0) ...[const SizedBox(width: 6), Tag('$ambCount 待确认', color: Tone.moss, filled: true)],
              if (earlyCount > 0) ...[const SizedBox(width: 6), Tag('$earlyCount 提前', color: Tone.moss)],
            ],
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Framed(
            child: ListView.separated(
              itemCount: s.messages.length,
              separatorBuilder: (_, _) => const HairRule(),
              itemBuilder: (_, i) {
                final m = s.messages[i];
                return _MessageRow(
                  msg: m,
                  parsed: parsedByOrder[m.order],
                  isAnchor: s.anchorOrder != 0 && s.anchorOrder == m.order,
                  beforeAnchor: m.order < s.anchorOrder,
                  isAuthor: s.authorName == m.sender,
                  early: s.isEarly(m),
                  onTap: () => s.setAnchor(m.order),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageRow extends StatelessWidget {
  final RawMessage msg;
  final ParsedMessage? parsed;
  final bool isAnchor;
  final bool beforeAnchor;
  final bool isAuthor;
  final bool early;
  final VoidCallback onTap;
  const _MessageRow({required this.msg, required this.parsed, required this.isAnchor, required this.beforeAnchor, required this.isAuthor, required this.early, required this.onTap});

  String _time() {
    final t = msg.time;
    if (t == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final p = parsed;
    final muted = beforeAnchor || isAuthor;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: isAnchor ? Tone.cream : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Opacity(
            opacity: muted ? 0.4 : 1,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 30,
                  child: Text(isAnchor ? '▶' : '${msg.order + 1}', style: Tone.num.copyWith(fontSize: 12, color: isAnchor ? Tone.ink : Tone.inkMute)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(msg.sender, style: Tone.body.copyWith(fontWeight: FontWeight.w700)),
                          Text(_time(), style: Tone.num.copyWith(fontSize: 12.5, color: Tone.inkMute)),
                          if (isAuthor) const Tag('作者'),
                          if (early) const Tag('提前 · 排最后', color: Tone.moss),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(msg.text, style: Tone.body),
                      if (p != null && p.hasNumbers) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final n in p.claims) Tag('$n'),
                            for (final n in p.cancels) Tag('$n', strike: true, color: Tone.moss),
                            if (p.status == ParseStatus.ambiguous) const Tag('待确认', filled: true, color: Tone.moss),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (p != null && p.status == ParseStatus.noise) Text('—', style: Tone.bodySoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
