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

  test('loads a legacy save and keeps a new Legendary fish through a sale', () {
    final saved = Pond.starter().toJson()..remove('raritySeed');
    final fish = (saved['fish']! as List).cast<Map<String, Object>>();
    for (final item in fish) {
      item.remove('isComet');
    }
    final pond = Pond.fromJson(saved);
    expect(pond.fish.every((item) => !item.isComet), isTrue);

    final comet = Fish.fromJson({
      ...pond.fish[2].toJson(),
      'isComet': true,
      'tail': Tail.violet.name,
    });
    expect(comet.price, pond.fish[2].price * 3);
    pond.fish[2] = comet;
    expect(pond.candidate, comet);

    pond.sell(keepCandidate: true);
    final restored = Pond.fromJson(pond.toJson());
    expect(restored.breeders, contains(comet.id));
    expect(
      restored.fish.singleWhere((item) => item.id == comet.id).isComet,
      isTrue,
    );
    expect(restored.raritySeed, pond.raritySeed);
  });

  test('applies the same birth roll to mutation and inheritance', () {
    // The first roll for each seed falls between the relevant probability cutoffs.
    for (final (parents, seed, expected) in [
      (0, 1972, true),
      (0, 1974, false),
      (1, 2023, true),
      (1, 2126, false),
      (2, 2126, true),
      (2, 2358, false),
    ]) {
      final pond = Pond.starter()..raritySeed = seed;
      for (var index = 0; index < parents; index++) {
        pond.fish[index] = Fish.fromJson({
          ...pond.fish[index].toJson(),
          'isComet': true,
        });
      }
      final firstNewborn = pond.nextId;
      final report = pond.advance(const Duration(seconds: 4 * Pond.daySeconds));
      expect(report.born, greaterThan(0));
      expect(
        pond.fish.singleWhere((item) => item.id == firstNewborn).isComet,
        expected,
        reason: 'parents: $parents, seed: $seed',
      );
      expect(
        report.cometsBorn,
        pond.fish
            .where((fish) => fish.id >= firstNewborn && fish.isComet)
            .length,
      );
    }
  });
}
