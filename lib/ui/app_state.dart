import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import '../core/core.dart';
import 'package:file_selector/file_selector.dart' show XFile;

import '../platform/ops.dart' as ops;
import '../platform/picked.dart';

enum Stage { images, chat, result, export }

enum SortMode { name, mtime }

class AppState extends ChangeNotifier {
  Stage stage = Stage.images;

  /// 测试用：强制按桌面 / 手机 / 网页渲染
  static bool? desktopOverride;
  static bool? webOverride;
  static bool get isWeb => webOverride ?? ops.isWeb;
  static bool get isDesktop => desktopOverride ?? ops.isDesktop;
  static bool get isMobile => !isWeb && !isDesktop;
  static bool get isAndroid => ops.isAndroid;
  static bool get canPickFolder => isDesktop && ops.canPickFolder;

  // ---- 图片 ----
  String? imageDir;
  /// 当前顺序的图片 id（桌面 / 手机 = 路径，网页 = 内存键）
  List<String> sourcePaths = [];
  final Map<String, DateTime> _mtimes = {};
  final Map<String, String> _names = {};
  ImageIndex? images;
  /// 导入进度（选图 / 读取时给用户看，避免以为手机卡住）
  bool importing = false;
  int importDone = 0;
  int importTotal = 0;
  String importNote = '';
  /// 无图模式：只填编号总数，不选图片
  int? manualMax;
  bool get textOnly => images == null && manualMax != null;
  NumberRule numberRule = NumberRule.firstNumber;
  SortMode sortMode = SortMode.name;

  // ---- 聊天 ----
  String chatText = '';
  List<RawMessage> messages = [];
  List<ParsedMessage> parsed = [];

  // ---- 规则 ----
  int? defaultLimit;
  final Map<String, int> personLimits = {};
  Set<int> reserved = {};
  final Set<String> excluded = {};
  final Map<int, String?> manualOverrides = {};
  int anchorOrder = 0;
  String startTimeText = '';
  DateTime? startTime;
  String? authorName;
  final Set<int> approvedOrders = {};
  final Set<int> ignoredOrders = {};

  // ---- 输出 ----
  String? outputDir;
  bool renameToNumber = true;
  bool exporting = false;
  int exportDone = 0;
  int exportTotal = 0;
  ExportSummary? exportSummary;
  String? exportError;
  bool zipDone = false;
  final Set<String> saved = {};
  bool albumPerPerson = false;

  Allocation? allocation;

  // ---- 拼图设置（会话内沿用） ----
  int collagePerPage = 8;
  /// 每行大约几张竖图：3 宽松 / 4 标准 / 5 紧凑
  int collagePortraitsPerRow = 4;
  bool collageWatermark = true;

  CollageLayout get collageLayout {
    const width = 2000.0, margin = 44.0, gap = 28.0;
    final k = collagePortraitsPerRow;
    final rowH = (width - margin * 2 - gap * (k - 1)) / (k * 9 / 16);
    return CollageLayout(canvasWidth: width, margin: margin, gap: gap, targetRowHeight: rowH, maxPerPage: collagePerPage);
  }

  void setCollage({int? perPage, int? portraitsPerRow, bool? watermark}) {
    if (perPage != null) collagePerPage = perPage;
    if (portraitsPerRow != null) collagePortraitsPerRow = portraitsPerRow;
    if (watermark != null) collageWatermark = watermark;
    notifyListeners();
  }

  // ---- 轮次 ----
  int round = 1;
  /// 前几轮锁定的号：n -> (人名, 轮次)
  final Map<int, (String, int)> locked = {};
  final List<_RoundSnapshot> _history = [];
  Map<int, String> get lockedOwners => {for (final e in locked.entries) e.key: e.value.$1};
  int get lockedCount => locked.length;
  bool get canCancelRound => _history.isNotEmpty;

  int get maxNumber => images?.maxNumber ?? manualMax ?? 0;

  Rules get rules => Rules(
        maxNumber: maxNumber,
        defaultLimit: defaultLimit,
        personLimits: Map.of(personLimits),
        reserved: Set.of(reserved),
        excluded: Set.of(excluded),
        manualOverrides: Map.of(manualOverrides),
        preassigned: lockedOwners,
        anchorOrder: anchorOrder,
        startTime: startTime,
        authorName: authorName,
        approvedOrders: Set.of(approvedOrders),
        ignoredOrders: Set.of(ignoredOrders),
      );

  bool get imagesReady => (images != null && images!.ok) || (images == null && (manualMax ?? 0) > 0);
  bool get chatReady => parsed.isNotEmpty;
  bool get resultReady => allocation != null;
  bool isEarly(RawMessage m) => rules.isEarly(m);
  bool get exportDone_ => exportSummary != null || zipDone || saved.isNotEmpty;

  List<String> get senders {
    final seen = <String>{};
    return [for (final m in messages) if (seen.add(m.sender)) m.sender];
  }

  ImageProvider provider(String id) => ops.imageProvider(id);
  ImageProvider thumb(String id, int width) => ResizeImage(ops.imageProvider(id), width: width);

  void goTo(Stage s) {
    stage = s;
    notifyListeners();
  }

  // ---- 图片 ----
  /// 无图模式：设置编号总数（1..n）
  void setManualMax(int? n) {
    manualMax = (n == null || n <= 0) ? null : n.clamp(1, 9999);
    if (manualMax != null) {
      imageDir = null;
      sourcePaths = [];
      images = null;
    }
    _invalidate();
    _reparse();
    notifyListeners();
  }

  Future<void> loadFolder(String dir) async {
    manualMax = null;
    imageDir = dir;
    _setSources(await ops.listFolder(dir));
    _applySort();
    _reindex();
  }

  /// 多选 / 拖入的一批图：顺序即选择顺序，默认按顺序编号
  void loadPicked(List<PickedImage> picked) {
    if (picked.isEmpty) return;
    manualMax = null;
    imageDir = null;
    numberRule = NumberRule.sequential;
    _setSources(picked);
    _reindex();
  }

  Future<void> pickImages() async {
    _beginImport(isMobile ? '正在从相册读取，大图较多时需要几秒' : '正在读取…');
    try {
      final picked = await ops.pickImages(onProgress: _importProgress);
      _importNote('正在整理 ${picked.length} 张…');
      loadPicked(picked);
    } finally {
      _endImport();
    }
  }

  /// 外部（如安卓应用内相册）已选好文件时调用
  Future<void> importPicked(List<PickedImage> picked) async {
    _beginImport('正在整理 ${picked.length} 张…');
    try {
      await Future<void>.delayed(const Duration(milliseconds: 16)); // 让进度先画出来
      loadPicked(picked);
    } finally {
      _endImport();
    }
  }

  void _beginImport(String note) {
    importing = true;
    importDone = 0;
    importTotal = 0;
    importNote = note;
    notifyListeners();
  }

  DateTime _lastProgressNotify = DateTime.fromMillisecondsSinceEpoch(0);

  /// 节流：最多每 80ms 通知一次，避免大批量时反复重建页面
  void _importProgress(int done, int total) {
    importDone = done;
    importTotal = total;
    importNote = '正在读取 $done / $total';
    final now = DateTime.now();
    if (done == total || now.difference(_lastProgressNotify).inMilliseconds > 80) {
      _lastProgressNotify = now;
      notifyListeners();
    }
  }

  void _importNote(String n) {
    importNote = n;
    notifyListeners();
  }

  void _endImport() {
    importing = false;
    notifyListeners();
  }

  Future<void> pickFolder() async {
    final dir = await ops.pickFolder();
    if (dir != null) await loadFolder(dir);
  }

  Future<void> handleDrop(List<XFile> files) async {
    _beginImport('正在读取拖入的文件…');
    try {
      final r = await ops.fromDrop(files, onProgress: _importProgress);
      if (r.folder != null) {
        await loadFolder(r.folder!);
      } else {
        loadPicked(r.images);
      }
    } finally {
      _endImport();
    }
  }

  void _setSources(List<PickedImage> files) {
    sourcePaths = [for (final f in files) f.id];
    _mtimes.clear();
    _names.clear();
    for (final f in files) {
      _names[f.id] = f.name;
      if (f.mtime != null) _mtimes[f.id] = f.mtime!;
    }
  }

  String nameOf(String id) => _names[id] ?? p.basename(id);

  void _applySort() {
    switch (sortMode) {
      case SortMode.name:
        sourcePaths.sort((a, b) => _naturalCompare(nameOf(a), nameOf(b)));
      case SortMode.mtime:
        sourcePaths.sort((a, b) {
          final c = (_mtimes[a] ?? DateTime(0)).compareTo(_mtimes[b] ?? DateTime(0));
          return c != 0 ? c : _naturalCompare(nameOf(a), nameOf(b));
        });
    }
  }

  void _reindex() {
    images = sourcePaths.isEmpty ? null : ImageIndexer(rule: numberRule).index(sourcePaths, nameOf: nameOf);
    _invalidate();
    _reparse();
    notifyListeners();
  }

  void setNumberRule(NumberRule r) {
    numberRule = r;
    _reindex();
  }

  void setSortMode(SortMode m) {
    sortMode = m;
    _applySort();
    _reindex();
  }

  /// 把 [id] 移到 [toIndex]（按顺序编号时用）
  void moveImage(String id, int toIndex) {
    final from = sourcePaths.indexOf(id);
    if (from < 0) return;
    sourcePaths.removeAt(from);
    sourcePaths.insert(toIndex.clamp(0, sourcePaths.length), id);
    _reindex();
  }

  // ---- 聊天 ----
  void setChatText(String t) => chatText = t;

  void parseChat() {
    messages = ChatImporter().import(chatText);
    anchorOrder = 0;
    approvedOrders.clear();
    ignoredOrders.clear();
    manualOverrides.clear();
    excluded.clear();
    personLimits.clear();
    _parseStartTime();
    _reparse();
    notifyListeners();
  }

  void _reparse() {
    if (messages.isEmpty || maxNumber == 0) {
      parsed = [];
      allocation = null;
      return;
    }
    parsed = messages.map(NumberParser(maxNumber).parse).toList();
    recompute();
  }

  void _invalidate() {
    allocation = null;
    exportSummary = null;
    exportError = null;
    zipDone = false;
    saved.clear();
  }

  /// 本轮聊天与规则清空（图片、锁定的号不动）
  void _resetRoundInputs() {
    chatText = '';
    messages = [];
    parsed = [];
    anchorOrder = 0;
    startTimeText = '';
    startTime = null;
    personLimits.clear();
    excluded.clear();
    manualOverrides.clear();
    approvedOrders.clear();
    ignoredOrders.clear();
    _invalidate();
  }

  /// 开下一轮：锁定本轮已分出去的号，清空聊天，回到第 02 步
  void startNextRound() {
    final a = allocation;
    if (a == null) return;
    _history.add(_RoundSnapshot.capture(this));
    a.owner.forEach((n, who) {
      if (who != null && who != Allocation.reservedOwner && !locked.containsKey(n)) locked[n] = (who, round);
    });
    round++;
    _resetRoundInputs();
    stage = Stage.chat;
    notifyListeners();
  }

  /// 取消本轮，回到上一轮开轮前的状态
  void cancelRound() {
    if (_history.isEmpty) return;
    _history.removeLast().restore(this);
    recompute();
  }

  /// 新批次：全部清空
  void newBatch() {
    manualMax = null;
    imageDir = null;
    sourcePaths = [];
    images = null;
    numberRule = NumberRule.firstNumber;
    reserved = {};
    authorName = null;
    defaultLimit = null;
    round = 1;
    locked.clear();
    _history.clear();
    outputDir = null;
    _resetRoundInputs();
    stage = Stage.images;
    notifyListeners();
  }

  String get nextRoundMessage => allocation == null ? '' : Report.nextRoundMessage(round + 1, allocation!.unclaimed);

  // ---- 规则 ----
  void setAnchor(int order) {
    anchorOrder = anchorOrder == order ? 0 : order;
    recompute();
  }

  void setDefaultLimit(int? v) {
    defaultLimit = v;
    recompute();
  }

  void setPersonLimit(String name, int? v) {
    if (v == null) {
      personLimits.remove(name);
    } else {
      personLimits[name] = v;
    }
    recompute();
  }

  void setReservedText(String t) {
    reserved = NumberParser(maxNumber == 0 ? 9999 : maxNumber).parse(RawMessage(sender: '', time: null, order: 0, text: t)).claims.toSet();
    recompute();
  }

  static final _hhmm = RegExp(r'^\s*(\d{1,2})[:：](\d{2})\s*$');
  static final _full = RegExp(r'^\s*(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})\s+(\d{1,2})[:：](\d{2})\s*$');

  /// "22:00" → 以第一条带时间的消息的日期为准；也接受 "2026/08/30 22:00"
  void setStartTimeText(String t) {
    startTimeText = t;
    _parseStartTime();
    recompute();
  }

  void _parseStartTime() {
    final t = startTimeText;
    final full = _full.firstMatch(t);
    if (full != null) {
      startTime = DateTime(int.parse(full[1]!), int.parse(full[2]!), int.parse(full[3]!), int.parse(full[4]!), int.parse(full[5]!));
      return;
    }
    final hm = _hhmm.firstMatch(t);
    if (hm != null) {
      DateTime? base;
      for (final m in messages) {
        if (m.time != null) {
          base = m.time;
          break;
        }
      }
      base ??= DateTime.now();
      startTime = DateTime(base.year, base.month, base.day, int.parse(hm[1]!), int.parse(hm[2]!));
      return;
    }
    startTime = null;
  }

  void setAuthor(String? name) {
    authorName = name;
    recompute();
  }

  void toggleExcluded(String name) {
    if (!excluded.remove(name)) excluded.add(name);
    recompute();
  }

  void approve(int order) {
    approvedOrders.add(order);
    ignoredOrders.remove(order);
    recompute();
  }

  void ignore(int order) {
    ignoredOrders.add(order);
    approvedOrders.remove(order);
    recompute();
  }

  void override(int n, String? target, {bool clear = false}) {
    if (clear) {
      manualOverrides.remove(n);
    } else {
      manualOverrides[n] = target;
    }
    recompute();
  }

  void recompute() {
    allocation = (parsed.isEmpty || maxNumber == 0) ? null : Allocator().allocate(parsed, rules);
    exportSummary = null;
    exportError = null;
    zipDone = false;
    notifyListeners();
  }

  // ---- 输出 ----
  void ensureOutputDir() {
    outputDir ??= ops.defaultOutputDir(imageDir);
  }

  Future<void> pickOutputDir() async {
    final d = await ops.pickFolder();
    if (d != null) {
      outputDir = d;
      notifyListeners();
    }
  }

  void setRename(bool v) {
    renameToNumber = v;
    notifyListeners();
  }

  void setAlbumPerPerson(bool v) {
    albumPerPerson = v;
    notifyListeners();
  }

  /// 桌面：复制到子文件夹
  Future<void> runExport() async {
    if (allocation == null || images == null || outputDir == null) return;
    exporting = true;
    exportSummary = null;
    exportError = null;
    exportDone = 0;
    exportTotal = 0;
    notifyListeners();
    try {
      exportSummary = await ops.exportFolders(
        allocation: allocation!,
        images: images!,
        outputDir: outputDir!,
        rename: renameToNumber,
        onProgress: (d, t) {
          exportDone = d;
          exportTotal = t;
          notifyListeners();
        },
      );
    } catch (e) {
      exportError = e.toString();
    } finally {
      exporting = false;
      notifyListeners();
    }
  }

  /// 网页：打 ZIP 下载
  Future<void> runZip() async {
    if (allocation == null || images == null) return;
    exporting = true;
    exportError = null;
    zipDone = false;
    notifyListeners();
    try {
      final stamp = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      await ops.downloadZip(
        allocation: allocation!,
        images: images!,
        rename: renameToNumber,
        zipName: '分发_${stamp.year}${two(stamp.month)}${two(stamp.day)}_${two(stamp.hour)}${two(stamp.minute)}.zip',
      );
      zipDone = true;
    } catch (e) {
      exportError = e.toString();
    } finally {
      exporting = false;
      notifyListeners();
    }
  }

  /// 手机：保存某人的原图到相册
  Future<int> saveToPhotos(PersonResult person) async {
    final n = await ops.saveToPhotos(person, images!, album: albumPerPerson ? person.name : null, rename: renameToNumber);
    saved.add(person.name);
    notifyListeners();
    return n;
  }

  Future<void> revealOutput() async {
    if (exportSummary != null) await ops.revealFolder(exportSummary!.outputDir);
  }

  String get announcement => allocation == null ? '' : Report.announcement(allocation!, round: round);

  /// "张三：1, 3, 5"
  String personLine(PersonResult p) => '${p.name}：${Report.compress(p.got)}';
}

/// 自然排序：img2 < img10
int _naturalCompare(String a, String b) {
  final re = RegExp(r'(\d+)|(\D+)');
  final xa = re.allMatches(a).map((m) => m[0]!).toList();
  final xb = re.allMatches(b).map((m) => m[0]!).toList();
  for (var i = 0; i < xa.length && i < xb.length; i++) {
    final na = int.tryParse(xa[i]), nb = int.tryParse(xb[i]);
    final c = (na != null && nb != null) ? na.compareTo(nb) : xa[i].compareTo(xb[i]);
    if (c != 0) return c;
  }
  return xa.length.compareTo(xb.length);
}

/// 开轮前的快照，用于"取消本轮"
class _RoundSnapshot {
  final int round;
  final Map<int, (String, int)> locked;
  final String chatText;
  final List<RawMessage> messages;
  final int? defaultLimit;
  final Map<String, int> personLimits;
  final Set<String> excluded;
  final Map<int, String?> manualOverrides;
  final int anchorOrder;
  final String startTimeText;
  final Set<int> approvedOrders;
  final Set<int> ignoredOrders;

  _RoundSnapshot.capture(AppState s)
      : round = s.round,
        locked = Map.of(s.locked),
        chatText = s.chatText,
        messages = List.of(s.messages),
        defaultLimit = s.defaultLimit,
        personLimits = Map.of(s.personLimits),
        excluded = Set.of(s.excluded),
        manualOverrides = Map.of(s.manualOverrides),
        anchorOrder = s.anchorOrder,
        startTimeText = s.startTimeText,
        approvedOrders = Set.of(s.approvedOrders),
        ignoredOrders = Set.of(s.ignoredOrders);

  void restore(AppState s) {
    s.round = round;
    s.locked
      ..clear()
      ..addAll(locked);
    s.chatText = chatText;
    s.messages = List.of(messages);
    s.defaultLimit = defaultLimit;
    s.personLimits
      ..clear()
      ..addAll(personLimits);
    s.excluded
      ..clear()
      ..addAll(excluded);
    s.manualOverrides
      ..clear()
      ..addAll(manualOverrides);
    s.anchorOrder = anchorOrder;
    s.startTimeText = startTimeText;
    s.approvedOrders
      ..clear()
      ..addAll(approvedOrders);
    s.ignoredOrders
      ..clear()
      ..addAll(ignoredOrders);
    s._parseStartTime();
    s.parsed = s.messages.isEmpty || s.maxNumber == 0 ? [] : s.messages.map(NumberParser(s.maxNumber).parse).toList();
  }
}
