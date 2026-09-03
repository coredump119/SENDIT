import 'models.dart';

/// 先到先得 + 限量 的归属计算。全量重算，无状态。
class Allocator {
  Allocation allocate(List<ParsedMessage> messages, Rules rules) {
    final owner = <int, String?>{for (var n = 1; n <= rules.maxNumber; n++) n: null};
    for (final n in rules.reserved) {
      if (n >= 1 && n <= rules.maxNumber) owner[n] = Allocation.reservedOwner;
    }
    rules.preassigned.forEach((n, who) {
      if (n >= 1 && n <= rules.maxNumber) owner[n] = who;
    });
    final people = <String, PersonResult>{};
    final needsReview = <ParsedMessage>[];

    PersonResult personOf(ParsedMessage m) => people.putIfAbsent(
          m.raw.sender,
          () => PersonResult(name: m.raw.sender, firstOrder: m.raw.order),
        );

    // 提前（早于开始时间）的消息排到最后，其余按粘贴顺序
    int key(ParsedMessage m) => rules.isEarly(m.raw) ? 1 : 0;
    final sorted = [...messages]..sort((a, b) {
        final k = key(a).compareTo(key(b));
        return k != 0 ? k : a.raw.order.compareTo(b.raw.order);
      });

    for (final m in sorted) {
      if (m.raw.order < rules.anchorOrder) continue;
      if (rules.authorName != null && m.raw.sender == rules.authorName) continue;
      if (rules.excluded.contains(m.raw.sender)) continue;
      if (rules.ignoredOrders.contains(m.raw.order)) continue;

      if (m.status == ParseStatus.noise) continue;
      if (m.status == ParseStatus.ambiguous &&
          !rules.approvedOrders.contains(m.raw.order)) {
        needsReview.add(m);
        continue;
      }

      final p = personOf(m);
      final limit = rules.limitFor(p.name);

      for (final n in m.cancels) {
        if (owner[n] == p.name) {
          owner[n] = null;
          p.got.remove(n);
        }
      }

      for (final n in m.claims) {
        final cur = owner[n];
        if (cur == p.name) continue;
        if (cur != null) {
          final l = LostTo(n, cur);
          if (!p.lostTo.contains(l)) p.lostTo.add(l);
          continue;
        }
        if (limit != null && p.got.length >= limit) {
          if (!p.droppedByLimit.contains(n)) p.droppedByLimit.add(n);
          continue;
        }
        owner[n] = p.name;
        p.got.add(n);
      }
    }

    // 手动覆盖，绕过限量
    rules.manualOverrides.forEach((n, target) {
      if (n < 1 || n > rules.maxNumber) return;
      final cur = owner[n];
      if (cur != null && cur != Allocation.reservedOwner) {
        people[cur]?.got.remove(n);
      }
      owner[n] = target;
      if (target != null && target != Allocation.reservedOwner) {
        final p = people.putIfAbsent(
            target, () => PersonResult(name: target, firstOrder: 1 << 30));
        if (!p.got.contains(n)) p.got.add(n);
      }
    });

    final list = people.values.toList()
      ..sort((a, b) => a.firstOrder.compareTo(b.firstOrder));
    for (final p in list) {
      p.got.sort();
    }

    return Allocation(
      owner: owner,
      people: list,
      needsReview: needsReview,
      maxNumber: rules.maxNumber,
    );
  }
}
