import 'package:flutter/material.dart';

import 'theme.dart';

/// 圆角细线卡片
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color fill;
  final bool raised;
  final Color border;
  final double radius;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.fill = Tone.paper,
    this.raised = false,
    this.border = Tone.hair,
    this.radius = Tone.rPanel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 1),
        boxShadow: raised ? Tone.softShadow : null,
      ),
      child: child,
    );
  }
}

/// 圆角细线容器（不带内边距，给列表 / 文本区用）
class Framed extends StatelessWidget {
  final Widget child;
  final Color fill;
  final double radius;
  const Framed({super.key, required this.child, this.fill = Tone.paper, this.radius = Tone.rPanel});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(radius), border: Border.all(color: Tone.hair, width: 1)),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// 胶囊按钮
class SoftButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool small;
  final IconData? icon;
  const SoftButton({super.key, required this.label, required this.onPressed, this.primary = false, this.small = false, this.icon});
  @override
  State<SoftButton> createState() => _SoftButtonState();
}

class _SoftButtonState extends State<SoftButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final bg = !enabled
        ? Tone.inkFaint
        : widget.primary
            ? (_hover ? Tone.moss : Tone.ink)
            : (_hover ? Tone.cream : Tone.paper);
    final fg = !enabled ? Tone.inkMute : (widget.primary ? Tone.paper : Tone.ink);
    final border = !enabled ? Colors.transparent : (widget.primary ? Colors.transparent : Tone.hair);
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: EdgeInsets.symmetric(horizontal: widget.small ? 13 : 20, vertical: widget.small ? 8 : 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border, width: 1),
            boxShadow: enabled && widget.primary && !_down ? Tone.tinyShadow : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[Icon(widget.icon, size: widget.small ? 13 : 15, color: fg), const SizedBox(width: 6)],
              Text(widget.label, style: Tone.button.copyWith(color: fg, fontSize: widget.small ? 13 : 14.5)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 小标签：衬线大写宽字距
class Label extends StatelessWidget {
  final String text;
  final Color? color;
  const Label(this.text, {super.key, this.color});
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: color == null ? Tone.label : Tone.label.copyWith(color: color));
}

/// 小胶囊
class Tag extends StatelessWidget {
  final String text;
  final bool filled;
  final bool strike;
  final Color color;
  const Tag(this.text, {super.key, this.filled = false, this.strike = false, this.color = Tone.ink});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : (color == Tone.ink ? Tone.cream : Colors.transparent),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: filled ? color : (color == Tone.ink ? Colors.transparent : color), width: 1),
      ),
      child: Text(
        text,
        style: Tone.num.copyWith(
          fontSize: 12.5,
          color: filled ? Tone.paper : color,
          decoration: strike ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}

class HairRule extends StatelessWidget {
  const HairRule({super.key});
  @override
  Widget build(BuildContext context) => Container(height: 1, color: Tone.hairSoft);
}

class HeaderRule extends StatelessWidget {
  const HeaderRule({super.key});
  @override
  Widget build(BuildContext context) => Container(height: 1, color: Tone.hair);
}

/// 无框统计：大衬线数字 + 小标签
class InlineStat extends StatelessWidget {
  final String label;
  final String value;
  final bool warn;
  const InlineStat({super.key, required this.label, required this.value, this.warn = false});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: Tone.numeral.copyWith(color: warn ? Tone.moss : Tone.ink, fontSize: value.length > 6 ? 18 : 30)),
        const SizedBox(height: 4),
        Label(label, color: warn ? Tone.moss : Tone.inkMute),
      ],
    );
  }
}

class PageHeader extends StatelessWidget {
  final String index;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool compact;
  const PageHeader({super.key, required this.index, required this.title, this.subtitle, this.actions = const [], this.compact = false});
  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Label('Step $index'),
        const SizedBox(height: 6),
        Text(title, style: compact ? Tone.display.copyWith(fontSize: 28) : Tone.display),
        if (subtitle != null) ...[const SizedBox(height: 6), Text(subtitle!, style: Tone.bodySoft)],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compact) ...[
          titleBlock,
          if (actions.isNotEmpty) ...[const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: actions)],
        ] else
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: titleBlock), ...actions.expand((a) => [const SizedBox(width: 8), a])]),
        SizedBox(height: compact ? 12 : 16),
        const HeaderRule(),
        SizedBox(height: compact ? 14 : 20),
      ],
    );
  }
}

class NumField extends StatefulWidget {
  final int? value;
  final String hint;
  final ValueChanged<int?> onChanged;
  final double width;
  const NumField({super.key, required this.value, required this.onChanged, this.hint = '∞', this.width = 60});
  @override
  State<NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<NumField> {
  late final TextEditingController _c = TextEditingController(text: widget.value?.toString() ?? '');
  @override
  void didUpdateWidget(covariant NumField old) {
    super.didUpdateWidget(old);
    final t = widget.value?.toString() ?? '';
    if (t != _c.text && widget.value != int.tryParse(_c.text)) _c.text = t;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: TextField(
        controller: _c,
        style: Tone.num,
        textAlign: TextAlign.center,
        decoration: InputDecoration(hintText: widget.hint),
        onChanged: (t) => widget.onChanged(int.tryParse(t.trim())),
      ),
    );
  }
}

/// 分段开关（胶囊）
class Segmented<T> extends StatelessWidget {
  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;
  const Segmented({super.key, required this.items, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: Tone.cream, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (v, name) in items)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: v == value ? Tone.paper : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: v == value ? Tone.tinyShadow : null,
                  ),
                  child: Text(name, style: Tone.body.copyWith(fontSize: 12.5, height: 1.2, color: v == value ? Tone.ink : Tone.inkSoft, fontWeight: v == value ? FontWeight.w600 : FontWeight.w400)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class Field extends StatelessWidget {
  final String label;
  final Widget child;
  const Field({super.key, required this.label, required this.child});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [Label(label), const SizedBox(height: 6), child],
    );
  }
}

class EmptyNote extends StatelessWidget {
  final String text;
  const EmptyNote(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Tone.rPanel), border: Border.all(color: Tone.hairSoft, width: 1)),
      child: Center(child: Text(text, style: Tone.h3.copyWith(color: Tone.inkMute))),
    );
  }
}

/// 圆形勾选
class Check extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const Check({super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: value ? Tone.ink : Tone.paper, shape: BoxShape.circle, border: Border.all(color: value ? Tone.ink : Tone.hair, width: 1)),
          child: value ? const Icon(Icons.check, size: 13, color: Tone.paper) : null,
        ),
      ),
    );
  }
}

/// 二次确认
Future<bool> confirmDialog(BuildContext context, {required String title, required String body, String confirm = '确定'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Tone.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tone.rPanel)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Tone.h2),
            const SizedBox(height: 8),
            Text(body, style: Tone.body),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SoftButton(label: '取消', small: true, onPressed: () => Navigator.of(ctx).pop(false)),
                const SizedBox(width: 8),
                SoftButton(label: confirm, small: true, primary: true, onPressed: () => Navigator.of(ctx).pop(true)),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return r == true;
}
