import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/core.dart';
import '../app_state.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets.dart';

class ExportPage extends StatefulWidget {
  const ExportPage({super.key});
  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  bool _copied = false;
  String? _saving;
  String? _error;

  @override
  void initState() {
    super.initState();
    AppScope.read(context).ensureOutputDir();
  }

  Future<void> _copyAnnouncement(AppState s) async {
    await Clipboard.setData(ClipboardData(text: s.announcement));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _confirmNextRound(AppState s) async {
    final a = s.allocation!;
    final ok = await showDialog<bool>(
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
              Text('开启第 ${s.round + 1} 轮', style: Tone.h2),
              const SizedBox(height: 8),
              Text('本轮已分出去的号会锁定，编号保持不变。第 ${s.round + 1} 轮只能扣剩下的 ${a.unclaimed.length} 张。\n开启后回到"聊天"页粘贴新一轮的记录。', style: Tone.body),
              const SizedBox(height: 12),
              Framed(child: Padding(padding: const EdgeInsets.all(12), child: SelectableText(s.nextRoundMessage, style: Tone.body))),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SoftButton(label: '取消', small: true, onPressed: () => Navigator.of(ctx).pop(false)),
                  const SizedBox(width: 8),
                  SoftButton(label: '复制群消息', small: true, onPressed: () => _copyText(s.nextRoundMessage)),
                  const SizedBox(width: 8),
                  SoftButton(label: '开启', small: true, primary: true, onPressed: () => Navigator.of(ctx).pop(true)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) s.startNextRound();
  }

  /// 底部"还有 N 张未认领 → 开启下一轮"
  Widget _nextRoundPanel(AppState s, Allocation a) {
    if (a.unclaimed.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Panel(
        fill: Tone.cream,
        border: Colors.transparent,
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('还有 ${a.unclaimed.length} 张未认领', style: Tone.h3),
                  const SizedBox(height: 2),
                  Text('${Report.compress(a.unclaimed)}${s.round > 1 ? '  ·  当前第 ${s.round} 轮' : ''}', style: Tone.bodySoft),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SoftButton(label: '开启第 ${s.round + 1} 轮', small: true, primary: true, icon: Icons.replay_rounded, onPressed: () => _confirmNextRound(s)),
          ],
        ),
      ),
    );
  }

  Future<void> _save(AppState s, PersonResult person) async {
    setState(() {
      _saving = person.name;
      _error = null;
    });
    try {
      await s.saveToPhotos(person);
    } catch (e) {
      if (mounted) setState(() => _error = '保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final a = s.allocation;
    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxWidth < 700;
      final mode = s.textOnly ? _Mode.text : (AppState.isMobile ? _Mode.photos : (AppState.isWeb ? _Mode.zip : _Mode.folders));
      final subtitle = switch (mode) {
        _Mode.text => '无图模式：按人列出号码，点右侧复制单个人的，或复制整份群公告。',
        _Mode.folders => '每人一个文件夹，只复制不移动。之后在微信里打开对应聊天，全选文件夹里的图发送即可。',
        _Mode.zip => '打包成一个 ZIP 下载，解压后每人一个文件夹。全部在浏览器里完成，不经过任何服务器。',
        _Mode.photos => '一人一组，点"保存到相册"把原图存进手机，再到微信里选图发送（记得勾"原图"）。',
      };
      Widget body() => switch (mode) {
            _Mode.text => _textResult(s, a!),
            _Mode.photos => _saveList(s, a!),
            _Mode.zip => _zip(s, a!, compact),
            _Mode.folders => _folders(s, a!, compact),
          };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            index: '04',
            title: (mode == _Mode.text ? '结果' : mode == _Mode.photos ? '分发' : '拆分') + (s.round > 1 ? ' · 第 ${s.round} 轮' : ''),
            compact: compact,
            subtitle: s.round > 1 ? '只包含第 ${s.round} 轮新分出去的图，前几轮已经发过的不会重复。' : subtitle,
            actions: [SoftButton(label: _copied ? '已复制' : '复制群公告', small: compact, onPressed: a == null ? null : () => _copyAnnouncement(s))],
          ),
          if (a == null)
            const Expanded(child: EmptyNote('先完成前面三步'))
          else if (mode == _Mode.photos || mode == _Mode.text || compact)
            Expanded(child: body())
          else
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 6, child: body()),
                  const SizedBox(width: 24),
                  Expanded(flex: 5, child: _announcement(s)),
                ],
              ),
            ),
        ],
      );
    });
  }

  // ---- 无图模式：按人列号码 ----
  Widget _textResult(AppState s, Allocation a) {
    final people = a.people.where((p) => p.got.isNotEmpty).toList();
    return ListView(
      children: [
        for (final person in people)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(person.name, style: Tone.h2.copyWith(fontSize: 20), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('${person.got.length} 张 · ${Report.compress(person.got)}', style: Tone.num.copyWith(fontSize: 14, color: Tone.inkSoft)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SoftButton(label: '复制', small: true, icon: Icons.copy_rounded, onPressed: () => _copyText(s.personLine(person))),
                ],
              ),
            ),
          ),
        if (a.unclaimed.isNotEmpty) Text('未认领：${Report.compress(a.unclaimed)}', style: Tone.bodySoft),
        const SizedBox(height: 16),
        const Label('群公告'),
        const SizedBox(height: 6),
        _announcementBox(s, height: 220),
        _nextRoundPanel(s, a),
        const SizedBox(height: 12),
      ],
    );
  }

  // ---- 手机：按人保存到相册 ----
  Widget _saveList(AppState s, Allocation a) {
    final people = a.people.where((p) => p.got.isNotEmpty).toList();
    return ListView(
      children: [
        Row(
          children: [
            Check(value: s.albumPerPerson, onChanged: s.setAlbumPerPerson),
            const SizedBox(width: 10),
            Expanded(child: Text('每人单独建一个相册（默认只进"最近项目"，保存后在微信里选最近的几张即可）', style: Tone.bodySoft)),
          ],
        ),
        const SizedBox(height: 14),
        if (_error != null) ...[Panel(fill: Tone.cream, border: Colors.transparent, child: Text(_error!, style: Tone.body.copyWith(color: Tone.moss))), const SizedBox(height: 10)],
        for (final person in people)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Panel(
              raised: true,
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(person.name, style: Tone.h2.copyWith(fontSize: 20), overflow: TextOverflow.ellipsis)),
                      if (s.saved.contains(person.name)) ...[const Tag('已保存', filled: true), const SizedBox(width: 8)],
                      SoftButton(
                        label: _saving == person.name ? '保存中…' : '保存到相册',
                        primary: !s.saved.contains(person.name),
                        small: true,
                        icon: Icons.arrow_downward_rounded,
                        onPressed: _saving != null ? null : () => _save(s, person),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${person.got.length} 张 · ${Report.compress(person.got)}', style: Tone.num.copyWith(fontSize: 13.5, color: Tone.inkSoft)),
                  const SizedBox(height: 10),
                  _strip(s, person),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        const Label('群公告'),
        const SizedBox(height: 6),
        _announcementBox(s, height: 200),
        _nextRoundPanel(s, a),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _strip(AppState s, PersonResult person) {
    return SizedBox(
      height: 58,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final n in person.got)
            if (s.images!.byNumber[n] != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(width: 58, child: Image(image: s.thumb(s.images!.byNumber[n]!, 120), fit: BoxFit.cover)),
                ),
              ),
        ],
      ),
    );
  }

  List<(String, int)> _folderList(Allocation a) => [
        for (final person in a.people) if (person.got.isNotEmpty) (Report.folderName(person), person.got.length),
        if (a.unclaimed.isNotEmpty) ('_未认领 (${a.unclaimed.length}张)', a.unclaimed.length),
      ];

  Widget _folderPreview(List<(String, int)> folders) {
    return Framed(
      child: ListView.separated(
        itemCount: folders.length,
        separatorBuilder: (_, _) => const HairRule(),
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(children: [Expanded(child: Text(folders[i].$1, style: Tone.body)), Text('${folders[i].$2}', style: Tone.num.copyWith(color: Tone.inkSoft))]),
        ),
      ),
    );
  }

  Widget _renameRow(AppState s) {
    return Row(
      children: [
        Check(value: s.renameToNumber, onChanged: s.setRename),
        const SizedBox(width: 10),
        Expanded(child: Text('把文件名改成编号（05.png），方便对方核对', style: Tone.body)),
      ],
    );
  }

  // ---- 网页：ZIP ----
  Widget _zip(AppState s, Allocation a, bool compact) {
    final folders = _folderList(a);
    final total = folders.fold<int>(0, (x, f) => x + f.$2);
    return _scrollIfCompact(
      compact,
      children: [
        _renameRow(s),
        const SizedBox(height: 18),
        Label('ZIP 里将有 ${folders.length} 个文件夹 · $total 张图'),
        const SizedBox(height: 6),
        compact ? SizedBox(height: 280, child: _folderPreview(folders)) : Expanded(child: _folderPreview(folders)),
        const SizedBox(height: 14),
        if (s.exporting)
          Row(children: [const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)), const SizedBox(width: 10), Text('正在打包…', style: Tone.bodySoft)])
        else if (s.exportError != null)
          Panel(fill: Tone.cream, border: Colors.transparent, child: Text('失败：${s.exportError}', style: Tone.body.copyWith(color: Tone.moss)))
        else
          Row(
            children: [
              SoftButton(label: s.zipDone ? '再下载一次' : '下载 ZIP', primary: !s.zipDone, icon: Icons.arrow_downward_rounded, onPressed: s.runZip),
              if (s.zipDone) ...[const SizedBox(width: 12), Text('已开始下载，解压后每人一个文件夹。', style: Tone.bodySoft)],
            ],
          ),
        if (compact) ...[const SizedBox(height: 16), _announcementBox(s, height: 180)],
        _nextRoundPanel(s, a),
      ],
    );
  }

  // ---- 桌面：文件夹 ----
  Widget _folders(AppState s, Allocation a, bool compact) {
    final folders = _folderList(a);
    final sum = s.exportSummary;
    return _scrollIfCompact(
      compact,
      children: [
        const Label('输出到'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: Tone.paper, borderRadius: BorderRadius.circular(Tone.rSmall), border: Border.all(color: Tone.hair, width: 1)),
                child: Text(s.outputDir ?? '未选择', style: Tone.monoText, overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: 8),
            SoftButton(label: '更改', small: true, onPressed: s.pickOutputDir),
          ],
        ),
        const SizedBox(height: 12),
        _renameRow(s),
        const SizedBox(height: 18),
        Label('将创建 ${folders.length} 个文件夹'),
        const SizedBox(height: 6),
        compact ? SizedBox(height: 280, child: _folderPreview(folders)) : Expanded(child: _folderPreview(folders)),
        const SizedBox(height: 14),
        if (s.exporting) ...[
          ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: s.exportTotal == 0 ? null : s.exportDone / s.exportTotal, minHeight: 6)),
          const SizedBox(height: 6),
          Text('${s.exportDone} / ${s.exportTotal}', style: Tone.bodySoft),
        ] else if (sum != null)
          Panel(
            fill: Tone.ink,
            border: Colors.transparent,
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Expanded(child: Text('完成。${sum.filesCopied} 张图 → ${sum.folders.length} 个文件夹', style: Tone.h3.copyWith(color: Tone.paper))),
                SoftButton(label: '打开文件夹', small: true, onPressed: s.revealOutput),
              ],
            ),
          )
        else if (s.exportError != null)
          Panel(fill: Tone.cream, border: Colors.transparent, child: Text('失败：${s.exportError}', style: Tone.body.copyWith(color: Tone.moss)))
        else
          Row(children: [SoftButton(label: '开始拆分', primary: true, onPressed: s.outputDir == null ? null : s.runExport)]),
        if (compact) ...[const SizedBox(height: 16), _announcementBox(s, height: 180)],
        _nextRoundPanel(s, a),
      ],
    );
  }

  Widget _scrollIfCompact(bool compact, {required List<Widget> children}) => compact
      ? ListView(children: children)
      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);

  Widget _announcement(AppState s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [const Label('群公告'), const SizedBox(height: 6), Expanded(child: _announcementBox(s))],
    );
  }

  Widget _announcementBox(AppState s, {double? height}) {
    return SizedBox(
      height: height,
      child: Framed(
        child: Padding(padding: const EdgeInsets.all(16), child: SingleChildScrollView(child: SelectableText(s.announcement, style: Tone.body.copyWith(height: 1.7)))),
      ),
    );
  }
}

enum _Mode { folders, zip, photos, text }
