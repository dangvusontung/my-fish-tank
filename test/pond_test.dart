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

  test('migrates a version 1 save into corpses and per-species litters', () {
    final json = Pond.starter().toJson()
      ..['version'] = 1
      ..['dead'] = 2
      ..['nextLitter'] = 480.0
      ..['levels'] = {'feeder': 1, 'filter': 2, 'javaMoss': 1}
      ..remove('pairSpawns')
      ..remove('feederMode')
      ..remove('corpses')
      ..remove('clutches');
    for (final fish in json['fish'] as List<Map<String, Object>>) {
      fish.remove('species');
    }

    final pond = Pond.fromJson(jsonDecode(jsonEncode(json)));

    expect(pond.dead, 2);
    expect(pond.nextLitter[Species.guppy], 480);
    expect(pond.levels[Equipment.storage], 0);
    expect(pond.levels[Equipment.filter], 2);
    expect(pond.ownedSpecies, {Species.guppy});
    expect(Pond.fromJson(pond.toJson()).toJson(), pond.toJson());
  });

  test('snails eat corpses offline while unscooped corpses foul water', () {
    final idle = _withCorpses(Pond.starter(), 3);
    final cleaned = _withCorpses(Pond.starter(), 3)
      ..levels[Equipment.snails] = 1;

    idle.advance(const Duration(hours: 1));
    final report = cleaned.advance(const Duration(hours: 1));

    expect(idle.dead, 3);
    expect(cleaned.dead, 0);
    expect(report.scavenged, 3);
    expect(cleaned.water, greaterThan(idle.water));
  });

  test('scoops corpses one at a time or all at once', () {
    final pond = _withCorpses(Pond.starter(), 3);
    final first = pond.corpses.first.id;

    expect(pond.scoop(first), isTrue);
    expect(pond.scoop(first), isFalse);
    expect(pond.dead, 2);
    pond.scoopAll();
    expect(pond.dead, 0);
  });

  test('food storage needs a feeder and refills to capacity', () {
    final pond = Pond.starter()..coins = 1000;
    expect(pond.canUpgrade(Equipment.storage), isFalse);

    pond.upgrade(Equipment.feeder);
    expect(pond.stock, 26);
    expect(pond.upgrade(Equipment.storage), isTrue);
    expect(pond.capacity, 46);

    final cost = pond.refillCost;
    final coins = pond.coins;
    pond.refill();
    expect(pond.stock, 46);
    expect(pond.coins, coins - cost);
  });

  test('a dense feeder keeps fish fuller than a sparse one', () {
    Pond run(FeederMode mode) => Pond.starter()
      ..coins = 1000
      ..upgrade(Equipment.feeder)
      ..feederMode = mode
      ..advance(const Duration(minutes: 30));

    expect(
      run(FeederMode.dense).satiety,
      greaterThan(run(FeederMode.sparse).satiety),
    );
  });

  test('egg layers lay a clutch that hatches into fry', () {
    final pond = Pond.starter()..coins = 1000;
    expect(pond.buyPair(Species.corydoras), isTrue);
    expect(pond.pairOf(Species.corydoras), hasLength(2));

    final report = pond.advance(const Duration(seconds: 10 * Pond.daySeconds));

    expect(report.laid, inInclusiveRange(100, 200));
    expect(report.hatched, inInclusiveRange(1, report.laid));
    expect(pond.count(Species.corydoras), greaterThan(2));
  });

  test('neon only spawn in clean water', () {
    final pond = Pond.starter()..coins = 1000;
    pond.buyPair(Species.neon);
    pond
      ..water = 55
      ..levels[Equipment.filter] = 0;

    pond.advance(const Duration(seconds: 6 * Pond.daySeconds));

    expect(pond.water, lessThan(70));
    expect(pond.clutches.where((c) => c.species == Species.neon), isEmpty);
    expect(pond.count(Species.neon), 2);
  });

  test('new species keep their broods and hatch schedules across saves', () {
    const livebearers = [Species.platy, Species.swordtail];
    const eggLayers = [Species.zebrafish, Species.honeyGourami, Species.ram];
    final pond = Pond()..coins = 3000;
    for (final species in [...livebearers, ...eggLayers]) {
      expect(pond.buyPair(species), isTrue);
      expect(pond.pairOf(species), hasLength(2));
    }

    pond.advance(const Duration(seconds: 4 * Pond.daySeconds));
    for (final species in livebearers) {
      final litter = pond.litters.singleWhere(
        (litter) => litter.species == species,
      );
      expect(
        litter.born,
        inInclusiveRange(species.clutch.$1, species.clutch.$2 - 1),
      );
    }
    expect(
      pond.clutches.map((clutch) => clutch.species),
      unorderedEquals(eggLayers),
    );

    final restored = Pond.fromJson(jsonDecode(jsonEncode(pond.toJson())));
    restored.advance(const Duration(seconds: 3 * Pond.daySeconds));

    for (final species in eggLayers) {
      final litter = restored.litters.singleWhere(
        (litter) => litter.species == species,
      );
      expect(litter.born, inInclusiveRange(1, litter.eggs!));
      expect(restored.count(species), greaterThan(2));
    }
    expect(restored.clutches, isEmpty);
  });

  test(
    'zebrafish earn a school bonus only with six adults in the main tank',
    () {
      const species = Species.zebrafish;
      final pond = Pond()
        ..coins = 1000
        ..water = 100
        ..satiety = 100
        ..nurserySatiety = 100;
      expect(pond.upgrade(Equipment.nursery), isTrue);
      for (var pair = 0; pair < 3; pair++) {
        expect(pond.buyPair(species), isTrue);
      }
      expect(pond.income, closeTo(6 * species.adultIncome * 1.35, .001));

      expect(pond.moveFish(pond.fish.last.id, Zone.nursery), isTrue);

      expect(pond.adults(species, zone: Zone.main), 5);
      expect(pond.income, closeTo(6 * species.adultIncome * .7, .001));
    },
  );

  test('ram waits for clean water before spawning', () {
    final pond = Pond()..coins = 1000;
    expect(pond.buyPair(Species.ram), isTrue);
    pond
      ..water = 79
      ..nextLitter[Species.ram] = 0;

    pond.advance(const Duration(seconds: 1));
    expect(pond.clutches, isEmpty);

    pond.water = 80;
    pond.advance(const Duration(seconds: Pond.daySeconds));
    expect(pond.clutches.single.species, Species.ram);
  });

  test('rival betta males fight while the breeding male holds on', () {
    final pond = Pond.starter()..coins = 1000;
    pond.buyPair(Species.betta);
    final holder = pond
        .pairOf(Species.betta)
        .singleWhere((fish) => fish.sex == Sex.male);
    pond.buyPair(Species.betta);
    expect(pond.rivalBettas, 1);

    final report = pond.advance(const Duration(hours: 2));

    expect(report.fought, greaterThan(0));
    expect(pond.breeders, contains(holder.id));
  });

  test('forecast shows a filter paying off in a dirty pond', () {
    final pond = Pond.starter()..water = 30;
    final (now, next) = pond.forecast(Equipment.filter);

    expect(next, greaterThan(now));
    expect(pond.levels[Equipment.filter], 1);
    expect(pond.water, 30);
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

  test('upgrade cards show real effects and the feeder tops out', () {
    final pond = Pond.starter()..coins = 100000;

    expect(pond.effectAt(Equipment.feeder, 1), 'nghỉ 3 phút 55 giây');
    expect(pond.effectAt(Equipment.feeder, 2), 'nghỉ 3 phút 20 giây');
    expect(pond.effectAt(Equipment.storage, 1), '46 phần mồi');
    expect(pond.effectAt(Equipment.filter, 1), '0,54 điểm nước/phút');
    expect(pond.effectAt(Equipment.filter, 2), '1,08 điểm nước/phút');
    expect(pond.effectAt(Equipment.javaMoss, 2), '14 chỗ trú cá non');

    for (var level = 0; level < Pond.feederMaxLevel; level++) {
      expect(pond.upgrade(Equipment.feeder), isTrue);
    }
    expect(Pond.feedInterval(Pond.feederMaxLevel), 55);
    expect(pond.isMaxed(Equipment.feeder), isTrue);
    expect(pond.upgrade(Equipment.feeder), isFalse);
    expect(pond.flatReason(Equipment.storage), contains('Nạp thêm mồi'));
  });

  test('the nursery shelters newborns until they grow up', () {
    final open = Pond.starter();
    final nursery = Pond.starter()..levels[Equipment.nursery] = 1;

    final exposed = open.advance(const Duration(seconds: 12 * Pond.daySeconds));
    final sheltered = nursery.advance(
      const Duration(seconds: 12 * Pond.daySeconds),
    );

    expect(exposed.eaten, greaterThan(0));
    expect(sheltered.eaten, 0);
    expect(nursery.inZone(Zone.nursery), sheltered.born);

    final later = nursery.advance(const Duration(hours: 3));
    expect(later.graduated, greaterThan(0));
    expect(nursery.inZone(Zone.nursery), lessThan(sheltered.born));
  });

  test('rival betta males move into cups instead of fighting', () {
    final pond = Pond.starter()
      ..coins = 1000
      ..levels[Equipment.bettaCups] = 1;
    pond.buyPair(Species.betta);
    pond.buyPair(Species.betta);

    final report = pond.advance(const Duration(hours: 2));

    expect(report.housed, 1);
    expect(report.fought, 0);
    expect(pond.inZone(Zone.cups), 1);
    expect(pond.rivalBettas, 0);
  });

  test('litters are recorded and sold as a lot by growth stage', () {
    final pond = Pond.starter();
    final report = pond.advance(const Duration(seconds: 5 * Pond.daySeconds));
    final litter = pond.litters.single;

    expect(litter.born, report.born);
    expect(pond.alive(litter.id), greaterThan(0));
    expect(pond.sellableIn(litter.id), isEmpty, reason: 'still fry');

    pond.advance(const Duration(seconds: 25 * Pond.daySeconds));
    final lot = pond.sellableIn(litter.id);
    expect(lot, isNotEmpty);
    final young = lot.firstWhere((fish) => !fish.isAdult(pond.time));
    expect(pond.priceOf(young), inExclusiveRange(0, young.price));

    final restored = Pond.fromJson(jsonDecode(jsonEncode(pond.toJson())));
    expect(restored.toJson(), pond.toJson());

    final coins = pond.coins;
    final (count, earned) = pond.sellLitter(litter.id);
    expect(count, lot.length);
    expect(pond.coins, coins + earned);
    expect(pond.sellableIn(litter.id), isEmpty);
    expect(pond.litterLots, isNot(contains(litter.id)));
  });

  test('a breeder moved out of the main tank stops breeding', () {
    final pond = Pond.starter()..levels[Equipment.nursery] = 1;
    final male = pond.pairOf(Species.guppy).first;

    expect(pond.movesFor(male), contains(Zone.nursery));
    expect(pond.movesFor(male), isNot(contains(Zone.cups)));
    expect(pond.moveFish(male.id, Zone.nursery), isTrue);
    expect(pond.breeders, isNot(contains(male.id)));
    expect(pond.inZone(Zone.nursery), 1);
  });
}

Pond _withCorpses(Pond pond, int count) {
  final json = pond.toJson();
  json['corpses'] = [
    for (var i = 0; i < count; i++)
      Corpse(
        id: 900 + i,
        species: Species.guppy,
        tail: Tail.rose,
        diedAt: pond.time,
      ).toJson(),
  ];
  return Pond.fromJson(jsonDecode(jsonEncode(json)));
}
