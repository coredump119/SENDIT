
class RawMessage {
  final String sender;
  final DateTime? time;
  /// 在粘贴文本中的出现顺序（0 起），是排序的唯一依据。
  final int order;
  final String text;

  const RawMessage({
    required this.sender,
    required this.time,
    required this.order,
    required this.text,
  });

  @override
  String toString() => 'RawMessage(#$order $sender ${time ?? ''}: $text)';
}

enum ParseStatus {
  /// 提取到了有效认领/取消
  ok,
  /// 没有任何号（闲聊、表情、越界数字）
  noise,
  /// 有号但夹杂大量文字，需人工确认
  ambiguous,
}

class ParsedMessage {
  final RawMessage raw;
  final List<int> claims;
  final List<int> cancels;
  final ParseStatus status;
  /// 越界被丢掉的数字，仅用于展示
  final List<int> outOfRange;

  const ParsedMessage({
    required this.raw,
    required this.claims,
    required this.cancels,
    required this.status,
    this.outOfRange = const [],
  });

  bool get hasNumbers => claims.isNotEmpty || cancels.isNotEmpty;
}

class Rules {
  final int maxNumber;
  /// 全局限量，null = 不限
  final int? defaultLimit;
  final Map<String, int> personLimits;
  final Set<int> reserved;
  final Set<String> excluded;
  /// 手动指定归属：n -> 人名；n -> null 表示强制释放
  final Map<int, String?> manualOverrides;
  /// 前几轮已锁定的归属：n -> 人名。本轮不可再分配，扣了记为 lostTo。
  final Map<int, String> preassigned;
  /// 只处理 order >= anchorOrder 的消息
  final int anchorOrder;
  /// 开始时间：早于它的消息不丢弃，但排到所有正常消息之后再处理
  final DateTime? startTime;
  /// 作者昵称，作者消息不参与
  final String? authorName;
  /// 人工确认过的 ambiguous 消息（按 order）
  final Set<int> approvedOrders;
  final Set<int> ignoredOrders;

  const Rules({
    required this.maxNumber,
    this.defaultLimit,
    this.personLimits = const {},
    this.reserved = const {},
    this.excluded = const {},
    this.manualOverrides = const {},
    this.preassigned = const {},
    this.anchorOrder = 0,
    this.startTime,
    this.authorName,
    this.approvedOrders = const {},
    this.ignoredOrders = const {},
  });

  /// 是否"提前"（早于开始时间）
  bool isEarly(RawMessage m) =>
      startTime != null && m.time != null && m.time!.isBefore(startTime!);

  int? limitFor(String person) => personLimits[person] ?? defaultLimit;

  Rules copyWith({
    int? maxNumber,
    int? defaultLimit,
    bool clearDefaultLimit = false,
    Map<String, int>? personLimits,
    Set<int>? reserved,
    Set<String>? excluded,
    Map<int, String?>? manualOverrides,
    Map<int, String>? preassigned,
    int? anchorOrder,
    DateTime? startTime,
    bool clearStartTime = false,
    String? authorName,
    bool clearAuthor = false,
    Set<int>? approvedOrders,
    Set<int>? ignoredOrders,
  }) {
    return Rules(
      maxNumber: maxNumber ?? this.maxNumber,
      defaultLimit: clearDefaultLimit ? null : (defaultLimit ?? this.defaultLimit),
      personLimits: personLimits ?? this.personLimits,
      reserved: reserved ?? this.reserved,
      excluded: excluded ?? this.excluded,
      manualOverrides: manualOverrides ?? this.manualOverrides,
      preassigned: preassigned ?? this.preassigned,
      anchorOrder: anchorOrder ?? this.anchorOrder,
      startTime: clearStartTime ? null : (startTime ?? this.startTime),
      authorName: clearAuthor ? null : (authorName ?? this.authorName),
      approvedOrders: approvedOrders ?? this.approvedOrders,
      ignoredOrders: ignoredOrders ?? this.ignoredOrders,
    );
  }
}

class LostTo {
  final int number;
  /// 占用者人名，或 [Allocation.reservedOwner]
  final String to;
  const LostTo(this.number, this.to);

  @override
  bool operator ==(Object other) =>
      other is LostTo && other.number == number && other.to == to;
  @override
  int get hashCode => Object.hash(number, to);
  @override
  String toString() => '$number→$to';
}

class PersonResult {
  final String name;
  final List<int> got;
  final List<LostTo> lostTo;
  final List<int> droppedByLimit;
  /// 该人第一次出现的消息 order，用于稳定排序
  final int firstOrder;

  PersonResult({
    required this.name,
    required this.firstOrder,
    List<int>? got,
    List<LostTo>? lostTo,
    List<int>? droppedByLimit,
  })  : got = got ?? [],
        lostTo = lostTo ?? [],
        droppedByLimit = droppedByLimit ?? [];
}

class Allocation {
  static const reservedOwner = '_reserved';

  /// n -> 人名 / reservedOwner / null(未认领)
  final Map<int, String?> owner;
  /// 按首次出现顺序
  final List<PersonResult> people;
  final List<ParsedMessage> needsReview;
  final int maxNumber;

  const Allocation({
    required this.owner,
    required this.people,
    required this.needsReview,
    required this.maxNumber,
  });

  PersonResult? person(String name) {
    for (final p in people) {
      if (p.name == name) return p;
    }
    return null;
  }

  List<int> get unclaimed =>
      [for (var n = 1; n <= maxNumber; n++) if (owner[n] == null) n];

  List<int> get reservedNumbers =>
      [for (var n = 1; n <= maxNumber; n++) if (owner[n] == reservedOwner) n];
}
