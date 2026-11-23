import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_fish_tank/src/pond.dart';

void main() {
  test('keeps the recommended fish and retains an opposite-sex breeder', () {
    final pond = Pond.starter();
    final chosen = pond.candidate!;
    final retained = pond.breeders.firstWhere(
      (id) => pond.fish.singleWhere((fish) => fish.id == id).sex != chosen.sex,
    );

    final (sold, earned) = pond.sell(keepCandidate: true);

    expect(sold, greaterThan(0));
    expect(pond.breeders, {retained, chosen.id});
    expect(pond.forSale, isEmpty);
    expect(pond.coins, 180 + earned);
  });

  test(
    'preserves offspring and keeps offline simulation within eight hours',
    () {
      final pond = Pond.starter();
      pond.upgrade(Equipment.feeder);
      final report = pond.advance(const Duration(hours: 72));

      expect(pond.time, Pond.maxOffline.inSeconds);
      expect(report.born, greaterThanOrEqualTo(20));
      expect(report.grown, greaterThan(0));
      expect(report.coins, greaterThan(0));
      expect(pond.stock, lessThan(26));
    },
  );

  test('resumes from a round-tripped save with deterministic births', () {
    final continuous = Pond.starter();
    continuous.advance(const Duration(minutes: 10));
    final restored = Pond.fromJson(
      jsonDecode(jsonEncode(continuous.toJson())) as Map<String, dynamic>,
    );
    const step = Duration(minutes: 20);

    final before = continuous.advance(step);
    final after = restored.advance(step);

    expect(after.born, before.born);
    expect(after.eaten, before.eaten);
    expect(restored.toJson(), continuous.toJson());
  });
}
