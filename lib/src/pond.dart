import 'dart:math' as math;

import 'species.dart';

export 'species.dart';

enum Tail {
  amber('đuôi cam'),
  violet('đuôi tím'),
  rose('đuôi hồng');

  const Tail(this.label);
  final String label;
}

enum Sex { male, female }

enum Equipment {
  feeder('Máy cho ăn', 'Rải mồi khi cá đói. Mỗi cấp rải nhanh hơn.', 115),
  storage('Kho mồi', 'Máy chứa thêm 20 phần mồi mỗi cấp.', 70),
  filter('Bộ lọc', 'Giảm chất thải trong hồ.', 95),
  javaMoss('Rêu Java', 'Cho cá con chỗ trú, giúp trứng cá chuột bám.', 75),
  snails('Ốc ramshorn', 'Thêm 3 ốc tự rỉa xác cá, kể cả lúc vắng nhà.', 60);

  const Equipment(this.label, this.detail, this.price);
  final String label;
  final String detail;
  final int price;
}

enum FeederMode {
  sparse('Thưa', 55),
  normal('Vừa', 70),
  dense('Dày', 88);

  const FeederMode(this.label, this.threshold);
  final String label;

  /// The feeder drops food while satiety is below this level.
  final double threshold;
}

class Fish {
  const Fish({
    required this.id,
    this.species = Species.guppy,
    required this.sex,
    required this.tail,
    required this.bornAt,
    required this.adultDay,
    required this.lifeDays,
    required this.vividness,
    this.isComet = false,
  });

  factory Fish.fromJson(Map<String, dynamic> json) => Fish(
    id: json['id'] as int,
    species: Species.values.byName(json['species'] as String? ?? 'guppy'),
    sex: Sex.values.byName(json['sex'] as String),
    tail: Tail.values.byName(json['tail'] as String),
    bornAt: (json['bornAt'] as num).toDouble(),
    adultDay: json['adultDay'] as int,
    lifeDays: json['lifeDays'] as int,
    vividness: json['vividness'] as int,
    isComet: json['isComet'] as bool? ?? false,
  );

  final int id;
  final Species species;
  final Sex sex;
  final Tail tail;
  final double bornAt;
  final int adultDay;
  final int lifeDays;
  final int vividness;

  /// Legendary comet-tail guppy variant.
  final bool isComet;

  double age(double time) => (time - bornAt) / Pond.daySeconds;
  double growth(double time) => (age(time) / adultDay).clamp(0, 1).toDouble();
  bool isAdult(double time) => age(time) >= adultDay;
  int get price =>
      (species.basePrice + vividness ~/ species.vividDivisor) *
      (isComet ? 3 : 1);

  Map<String, Object> toJson() => {
    'id': id,
    'species': species.name,
    'sex': sex.name,
    'tail': tail.name,
    'bornAt': bornAt,
    'adultDay': adultDay,
    'lifeDays': lifeDays,
    'vividness': vividness,
    'isComet': isComet,
  };
}

/// A dead fish lying on the floor. It fouls the water until it is scooped
/// out or snails have eaten all of it.
class Corpse {
  Corpse({
    required this.id,
    required this.species,
    required this.tail,
    required this.diedAt,
    this.remains = 1,
  });

  factory Corpse.fromJson(Map<String, dynamic> json) => Corpse(
    id: json['id'] as int,
    species: Species.values.byName(json['species'] as String),
    tail: Tail.values.byName(json['tail'] as String),
    diedAt: (json['diedAt'] as num).toDouble(),
    remains: (json['remains'] as num).toDouble(),
  );

  final int id;
  final Species species;
  final Tail tail;
  final double diedAt;
  double remains;

  /// Horizontal resting place as a fraction of the tank width.
  double get x => .1 + (id * .6180339 % 1) * .8;

  Map<String, Object> toJson() => {
    'id': id,
    'species': species.name,
    'tail': tail.name,
    'diedAt': diedAt,
    'remains': remains,
  };
}

/// Eggs from one spawning, hatching all at once at [hatchAt].
class Clutch {
  const Clutch({
    required this.id,
    required this.species,
    required this.eggs,
    required this.hatchAt,
    required this.tails,
    required this.vividness,
  });

  factory Clutch.fromJson(Map<String, dynamic> json) => Clutch(
    id: json['id'] as int,
    species: Species.values.byName(json['species'] as String),
    eggs: json['eggs'] as int,
    hatchAt: (json['hatchAt'] as num).toDouble(),
    tails: [
      for (final tail in json['tails'] as List<dynamic>)
        Tail.values.byName(tail as String),
    ],
    vividness: (json['vividness'] as List<dynamic>).cast<int>(),
  );

  final int id;
  final Species species;
  final int eggs;
  final double hatchAt;

  /// Traits of the two parents, inherited by the fry.
  final List<Tail> tails;
  final List<int> vividness;

  Map<String, Object> toJson() => {
    'id': id,
    'species': species.name,
    'eggs': eggs,
    'hatchAt': hatchAt,
    'tails': tails.map((tail) => tail.name).toList(),
    'vividness': vividness,
  };
}

class PondReport {
  int born = 0;
  int cometsBorn = 0;
  int laid = 0;
  int hatched = 0;
  int clutchesLost = 0;
  int grown = 0;
  int eaten = 0;
  int died = 0;
  int fought = 0;
  int fryLost = 0;
  int scavenged = 0;
  int coins = 0;

  bool get hasEvents =>
      born +
          laid +
          hatched +
          clutchesLost +
          grown +
          eaten +
          died +
          fought +
          fryLost +
          scavenged +
          coins >
      0;
}

class Pond {
  Pond();

  factory Pond.starter() {
    final pond = Pond();
    pond._addFish(age: 103, sex: Sex.male, tail: Tail.amber, vividness: 62);
    pond._addFish(age: 114, sex: Sex.female, tail: Tail.violet, vividness: 65);
    pond.breeders.addAll({1, 2});
    pond._addFish(age: 77, sex: Sex.male, tail: Tail.amber, vividness: 97);
    for (var i = 0; i < 4; i++) {
      pond._addFish(age: 80 + i * 3);
      pond._addFish(age: 22 + i * 8);
    }
    pond.nextLitter[Species.guppy] = 4 * daySeconds.toDouble();
    return pond;
  }

  factory Pond.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    if (version != 1 && version != 2) {
      throw const FormatException('Save version');
    }
    final pond = Pond()
      ..time = (json['time'] as num).toDouble()
      ..coins = (json['coins'] as num).toDouble()
      ..satiety = (json['satiety'] as num).toDouble()
      ..water = (json['water'] as num).toDouble()
      ..nextFeed = (json['nextFeed'] as num).toDouble()
      ..predation = (json['predation'] as num).toDouble()
      ..stock = json['stock'] as int
      ..nextId = json['nextId'] as int
      ..seed = json['seed'] as int
      ..preference = Tail.values.byName(json['preference'] as String);
    pond.raritySeed = json['raritySeed'] as int? ?? pond.raritySeed;
    final levels = json['levels'] as Map<String, dynamic>;
    for (final equipment in Equipment.values) {
      pond.levels[equipment] = levels[equipment.name] as int? ?? 0;
    }
    pond.breeders.addAll((json['breeders'] as List<dynamic>).cast<int>());
    pond.fish.addAll(
      (json['fish'] as List<dynamic>).map(
        (value) => Fish.fromJson(value as Map<String, dynamic>),
      ),
    );
    if (version == 1) {
      pond.nextLitter[Species.guppy] = (json['nextLitter'] as num).toDouble();
      for (var i = json['dead'] as int; i > 0; i--) {
        pond.corpses.add(
          Corpse(
            id: pond.nextId++,
            species: Species.guppy,
            tail: Tail.amber,
            diedAt: pond.time,
          ),
        );
      }
      return pond;
    }
    pond.feederMode = FeederMode.values.byName(json['feederMode'] as String);
    for (final entry in (json['nextLitter'] as Map<String, dynamic>).entries) {
      pond.nextLitter[Species.values.byName(entry.key)] = (entry.value as num)
          .toDouble();
    }
    for (final entry in (json['pairSpawns'] as Map<String, dynamic>).entries) {
      pond.pairSpawns[Species.values.byName(entry.key)] = entry.value as int;
    }
    pond.corpses.addAll(
      (json['corpses'] as List<dynamic>).map(
        (value) => Corpse.fromJson(value as Map<String, dynamic>),
      ),
    );
    pond.clutches.addAll(
      (json['clutches'] as List<dynamic>).map(
        (value) => Clutch.fromJson(value as Map<String, dynamic>),
      ),
    );
    return pond;
  }

  static const daySeconds = 120;
  static const maxOffline = Duration(hours: 8);
  static const waterChangeCost = 12;
  static const fryDays = 8;

  final List<Fish> fish = [];
  final List<Corpse> corpses = [];
  final List<Clutch> clutches = [];
  final Set<int> breeders = {};
  final Map<Equipment, int> levels = {
    Equipment.feeder: 0,
    Equipment.storage: 0,
    Equipment.filter: 1,
    Equipment.javaMoss: 1,
    Equipment.snails: 0,
  };
  final Map<Species, double> nextLitter = {};

  /// Spawnings by the current pair of each species.
  final Map<Species, int> pairSpawns = {};

  double time = 0;
  double coins = 180;
  double satiety = 72;
  double water = 94;
  double nextFeed = 0;
  double predation = 0;
  int stock = 0;
  int nextId = 1;
  int seed = 443016;
  int raritySeed = math.Random().nextInt(0x80000000);
  Tail preference = Tail.amber;
  FeederMode feederMode = FeederMode.normal;

  int get day => time ~/ daySeconds + 1;
  int get adultCount => fish.where((item) => item.isAdult(time)).length;
  int get juvenileCount => fish.length - adultCount;
  int get dead => corpses.length;
  int get sheltered => levels[Equipment.javaMoss]! * 7;
  int get snails => levels[Equipment.snails]! * 3;
  int get capacity => 26 + levels[Equipment.storage]! * 20;
  int get eggCount => clutches.fold(0, (total, clutch) => total + clutch.eggs);
  double get income => _income(time);

  /// Species with at least one living fish in the tank.
  Set<Species> get ownedSpecies => {for (final item in fish) item.species};

  int count(Species species) =>
      fish.where((item) => item.species == species).length;

  int adults(Species species) => fish
      .where((item) => item.species == species && item.isAdult(time))
      .length;

  List<Fish> pairOf(Species species) => fish
      .where((item) => item.species == species && breeders.contains(item.id))
      .toList();

  int? daysToLitter(Species species) {
    final due = nextLitter[species];
    if (due == null || pairOf(species).length < 2) return null;
    return math.max(1, ((due - time) / daySeconds).ceil());
  }

  /// Adult male bettas beyond the first, which fight instead of earning.
  int get rivalBettas => math.max(
    0,
    fish
            .where(
              (item) =>
                  item.species == Species.betta &&
                  item.sex == Sex.male &&
                  item.isAdult(time),
            )
            .length -
        1,
  );

  bool get canRepairBreeders => ownedSpecies.any((species) {
    final pair = pairOf(species);
    if (pair.length == 2) return false;
    if (species == Species.guppy) return true;
    return Sex.values.every(
      (sex) =>
          pair.any((item) => item.sex == sex) ||
          forSale.any((item) => item.species == species && item.sex == sex),
    );
  });

  List<Fish> get forSale => fish
      .where((item) => item.isAdult(time) && !breeders.contains(item.id))
      .toList();
  int get saleValue => forSale.fold(0, (total, fish) => total + fish.price);

  Fish? get candidate {
    Fish? best;
    for (final item in forSale) {
      if (item.species != Species.guppy) continue;
      if (!item.isComet && (item.tail != preference || item.age(time) > 220)) {
        continue;
      }
      final current = pairOf(Species.guppy)
          .where((parent) => parent.sex == item.sex)
          .firstOrNull;
      if (current != null) {
        if (current.isComet && !item.isComet) continue;
        if (current.isComet == item.isComet &&
            (item.isComet || current.tail == preference) &&
            _rank(item) <= _rank(current) + 7) {
          continue;
        }
      }
      if (best == null ||
          (item.isComet == best.isComet
              ? _rank(item) > _rank(best)
              : item.isComet)) {
        best = item;
      }
    }
    return best;
  }

  double _rank(Fish item) => item.vividness - .16 * item.age(time);

  double _income(double at) {
    final neonAdults = fish
        .where((item) => item.species == Species.neon && item.isAdult(at))
        .length;
    var bettaMales = 0;
    var total = 0.0;
    for (final item in fish) {
      final species = item.species;
      if (!item.isAdult(at)) {
        total += species.youngIncome;
        continue;
      }
      var value = species.adultIncome;
      if (species == Species.neon) {
        value *= neonAdults >= Species.neonSchool ? 1.35 : .7;
      }
      if (species == Species.betta &&
          item.sex == Sex.male &&
          bettaMales++ > 0) {
        value = 0;
      }
      total += value;
    }
    return total * (.30 + .70 * satiety / 100) * (.28 + .72 * water / 100);
  }

  double _hatchRate(Species species) => switch (species) {
    Species.corydoras => math.min(
      .8,
      species.hatchRate + levels[Equipment.javaMoss]! * .06,
    ),
    _ => species.hatchRate,
  };

  int _random(int upperBound) {
    seed = (1664525 * seed + 1013904223) & 0xffffffff;
    return (seed >> 8) % upperBound;
  }

  bool _rollComet(int cometParents) {
    final odds = switch (cometParents) {
      2 => .10,
      1 => .03,
      _ => .0005,
    };
    raritySeed = (1664525 * raritySeed + 1013904223) & 0xffffffff;
    return raritySeed / 0x100000000 < odds;
  }

  int _between((int, int) range) => range.$1 + _random(range.$2 - range.$1);

  void _addFish({
    Species species = Species.guppy,
    int age = 0,
    Sex? sex,
    Tail? tail,
    int? vividness,
    bool isComet = false,
  }) {
    fish.add(
      Fish(
        id: nextId++,
        species: species,
        sex: sex ?? Sex.values[_random(Sex.values.length)],
        tail: tail ?? Tail.values[_random(Tail.values.length)],
        bornAt: time - age * daySeconds,
        adultDay: _between(species.adultDays),
        lifeDays: _between(species.lifeDays),
        vividness: vividness ?? 42 + _random(45),
        isComet: isComet,
      ),
    );
  }

  void _bury(Fish item) {
    if (breeders.remove(item.id)) pairSpawns.remove(item.species);
    corpses.add(
      Corpse(id: item.id, species: item.species, tail: item.tail, diedAt: time),
    );
  }

  PondReport advance(Duration elapsed) {
    final report = PondReport();
    final previousCoins = coins.floor();
    final bounded = math.min(elapsed.inMilliseconds, maxOffline.inMilliseconds);
    var remaining = math.max(0, bounded) / 1000;
    while (remaining > 0.0001) {
      final step = math.min(30.0, remaining);
      _step(step, report);
      remaining -= step;
    }
    report.coins = coins.floor() - previousCoins;
    return report;
  }

  void _step(double step, PondReport report) {
    final before = time;
    var adultLoad = 0.0;
    var youngLoad = 0.0;
    var predators = 0.0;
    for (final item in fish) {
      if (item.isAdult(before)) {
        adultLoad += item.species.load;
        predators += item.species.predation;
      } else {
        youngLoad += item.species.load;
      }
    }
    time += step;
    if (fish.isNotEmpty) {
      satiety = math.max(
        0,
        satiety - step * (.0029 + adultLoad * .00024 + youngLoad * .00008),
      );
    }
    final feeder = levels[Equipment.feeder]!;
    if (feeder > 0 &&
        stock > 0 &&
        satiety < feederMode.threshold &&
        time >= nextFeed) {
      feed();
      stock--;
      nextFeed = time + math.max(55, 270 - 35 * feeder);
    }
    final cleanRate = .0037 + levels[Equipment.filter]! * .009;
    final wasteRate =
        adultLoad * .00031 + youngLoad * .00013 + corpses.length * .0048;
    water = (water + (cleanRate - wasteRate) * step).clamp(0, 100).toDouble();
    coins += _income(before) * step / 60;

    if (corpses.isNotEmpty && snails > 0) {
      var bites = snails * .4 * step / daySeconds;
      for (final corpse in corpses) {
        if (bites <= 0) break;
        final bite = math.min(bites, corpse.remains);
        corpse.remains -= bite;
        bites -= bite;
      }
      final remaining = corpses.length;
      corpses.removeWhere((corpse) => corpse.remains <= 1e-6);
      report.scavenged += remaining - corpses.length;
    }

    fish.removeWhere((item) {
      if (item.age(time) >= item.lifeDays) {
        _bury(item);
        report.died++;
        return true;
      }
      if (!item.isAdult(before) && item.isAdult(time)) report.grown++;
      return false;
    });

    _cull(step, report);
    _fight(step, report);
    for (final species in Species.values) {
      _spawn(species, report);
    }
    _hatch(report);
    _hunt(step, predators, report);
  }

  /// Hatched fry die off at their species' rate, faster when the pond is
  /// hungry or dirty.
  void _cull(double step, PondReport report) {
    final stress =
        1 + (1 - satiety / 100) + (water < 50 ? (50 - water) / 50 : 0);
    final chance = step / daySeconds * stress * 100000;
    fish.removeWhere((item) {
      final fryLoss = item.species.fryLoss;
      if (fryLoss == 0 || item.age(time) >= fryDays) return false;
      if (_random(100000) >= fryLoss * chance) return false;
      report.fryLost++;
      return true;
    });
  }

  void _fight(double step, PondReport report) {
    final males = fish
        .where(
          (item) =>
              item.species == Species.betta &&
              item.sex == Sex.male &&
              item.isAdult(time),
        )
        .toList();
    if (males.length < 2) return;
    // The breeding male, or else the first, holds the territory. Every rival
    // risks a fatal fight.
    final holder = males.firstWhere(
      (item) => breeders.contains(item.id),
      orElse: () => males.first,
    );
    for (final rival in males) {
      if (rival == holder) continue;
      if (_random(10000) >= 400 * step / daySeconds) continue;
      fish.remove(rival);
      _bury(rival);
      report.fought++;
    }
  }

  void _spawn(Species species, PondReport report) {
    final due = nextLitter[species];
    if (due == null || time < due) return;
    final parents = pairOf(species);
    if (parents.length != 2) return;
    final ready =
        satiety >= 25 &&
        water >= (species == Species.neon ? 70 : 50) &&
        parents.every((parent) => parent.isAdult(time));
    if (!ready) {
      nextLitter[species] = time + daySeconds;
      return;
    }
    final count = _between(species.clutch);
    if (species.brood == Brood.live) {
      final cometParents = parents.where((parent) => parent.isComet).length;
      for (var i = 0; i < count; i++) {
        final parent = parents[_random(parents.length)];
        final comet = species == Species.guppy && _rollComet(cometParents);
        _addFish(
          species: species,
          tail: _random(100) < 77 ? parent.tail : null,
          vividness: (parent.vividness + _random(31) - 15).clamp(28, 100),
          isComet: comet,
        );
        if (comet) report.cometsBorn++;
      }
      report.born += count;
    } else {
      final spawns = pairSpawns[species] ?? 0;
      pairSpawns[species] = spawns + 1;
      if (species == Species.angelfish && spawns == 0 && _random(2) == 0) {
        report.clutchesLost++;
      } else {
        clutches.add(
          Clutch(
            id: nextId++,
            species: species,
            eggs: count,
            hatchAt: time + species.incubation * daySeconds,
            tails: [for (final parent in parents) parent.tail],
            vividness: [for (final parent in parents) parent.vividness],
          ),
        );
        report.laid += count;
      }
    }
    nextLitter[species] = time + _between(species.spawnEvery) * daySeconds;
  }

  void _hatch(PondReport report) {
    final due = clutches.where((clutch) => time >= clutch.hatchAt).toList();
    for (final clutch in due) {
      clutches.remove(clutch);
      final variance = .85 + _random(31) / 100;
      final hatched = (clutch.eggs * _hatchRate(clutch.species) * variance)
          .round()
          .clamp(0, clutch.eggs);
      for (var i = 0; i < hatched; i++) {
        final parent = _random(2);
        _addFish(
          species: clutch.species,
          tail: _random(100) < 77 ? clutch.tails[parent] : null,
          vividness: (clutch.vividness[parent] + _random(31) - 15).clamp(
            28,
            100,
          ),
        );
      }
      report.hatched += hatched;
    }
  }

  void _hunt(double step, double predators, PondReport report) {
    final fry = fish.where((item) => item.age(time) < fryDays).toList();
    final exposed = math.max(0, fry.length - sheltered);
    if (exposed == 0 || predators == 0) {
      predation = 0;
      return;
    }
    predation += exposed * math.min(predators, 40) * step * .000012;
    final eaten = math.min(exposed, predation.floor());
    if (eaten == 0) return;
    final lost = fry.reversed.take(eaten).map((item) => item.id).toSet();
    fish.removeWhere((item) => lost.contains(item.id));
    report.eaten += eaten;
    predation -= eaten;
  }

  bool feed() {
    if (fish.isEmpty) return false;
    final portion = 24 / (1 + fish.length / 55);
    final excess = math.max(0.0, satiety + portion - 100);
    // Corydoras pick up leftovers before they rot.
    final leftovers = math.max(.5, 1 - .04 * adults(Species.corydoras));
    satiety = math.min(100, satiety + portion);
    water = math.max(0, water - .34 * excess * leftovers);
    return excess > 2;
  }

  int upgradeCost(Equipment equipment) =>
      (equipment.price * math.pow(1.6, levels[equipment]!)).round();

  bool canUpgrade(Equipment equipment) =>
      coins >= upgradeCost(equipment) &&
      (equipment != Equipment.storage || levels[Equipment.feeder]! > 0);

  bool upgrade(Equipment equipment) {
    if (!canUpgrade(equipment)) return false;
    coins -= upgradeCost(equipment);
    _install(equipment);
    return true;
  }

  void _install(Equipment equipment) {
    if (equipment == Equipment.feeder && levels[equipment] == 0) {
      stock = capacity;
    }
    levels[equipment] = levels[equipment]! + 1;
  }

  Pond copy() => Pond.fromJson(toJson());

  /// Average coins per minute over [horizon], without and with one more
  /// level of [equipment], simulated on copies of this pond.
  (double, double) forecast(
    Equipment equipment, {
    Duration horizon = const Duration(minutes: 30),
  }) {
    double earn(Pond pond) {
      final start = pond.coins;
      pond.advance(horizon);
      return (pond.coins - start) / horizon.inSeconds * 60;
    }

    return (earn(copy()), earn(copy().._install(equipment)));
  }

  int get refillCost => math.max(1, ((capacity - stock) * .72).ceil());

  void refill() {
    if (levels[Equipment.feeder] == 0 || stock >= capacity) return;
    if (coins < refillCost) return;
    coins -= refillCost;
    stock = capacity;
  }

  void changeWater() {
    if (coins < waterChangeCost || water >= 99) return;
    coins -= waterChangeCost;
    water = math.min(100, water + 30);
  }

  bool scoop(int id) {
    final before = corpses.length;
    corpses.removeWhere((corpse) => corpse.id == id);
    return corpses.length < before;
  }

  void scoopAll() => corpses.clear();

  void repairBreeders() {
    for (final species in ownedSpecies) {
      if (pairOf(species).length == 2) continue;
      for (final sex in Sex.values) {
        if (pairOf(species).any((item) => item.sex == sex)) continue;
        var replacement = forSale
            .where((item) => item.species == species && item.sex == sex)
            .firstOrNull;
        if (replacement == null && species == Species.guppy) {
          _addFish(age: 84, sex: sex);
          replacement = fish.last;
        }
        if (replacement != null) breeders.add(replacement.id);
      }
      if (pairOf(species).length == 2) {
        nextLitter[species] = time + 4 * daySeconds;
        pairSpawns.remove(species);
      }
    }
  }

  bool buyPair(Species species) {
    if (coins < species.pairCost) return false;
    coins -= species.pairCost;
    final pairComplete = pairOf(species).length == 2;
    for (final sex in Sex.values) {
      _addFish(species: species, age: species.adultDays.$2 + 2, sex: sex);
      if (!pairComplete && !pairOf(species).any((item) => item.sex == sex)) {
        breeders.add(fish.last.id);
      }
    }
    if (!pairComplete) {
      nextLitter[species] = time + 4 * daySeconds;
      pairSpawns.remove(species);
    }
    return true;
  }

  (int, int) sell({required bool keepCandidate}) {
    final sale = forSale;
    if (keepCandidate) {
      final selected = candidate;
      if (selected == null) return (0, 0);
      final old = pairOf(Species.guppy)
          .where((item) => item.sex == selected.sex)
          .firstOrNull;
      if (old != null) {
        breeders.remove(old.id);
        sale.add(old);
      }
      breeders.add(selected.id);
      sale.remove(selected);
    }
    final total = sale.fold(0, (sum, item) => sum + item.price);
    final sold = sale.map((item) => item.id).toSet();
    fish.removeWhere((item) => sold.contains(item.id));
    coins += total;
    return (sale.length, total);
  }

  Map<String, Object> toJson() => {
    'version': 2,
    'time': time,
    'coins': coins,
    'satiety': satiety,
    'water': water,
    'nextLitter': {
      for (final entry in nextLitter.entries) entry.key.name: entry.value,
    },
    'pairSpawns': {
      for (final entry in pairSpawns.entries) entry.key.name: entry.value,
    },
    'nextFeed': nextFeed,
    'predation': predation,
    'stock': stock,
    'nextId': nextId,
    'seed': seed,
    'raritySeed': raritySeed,
    'preference': preference.name,
    'feederMode': feederMode.name,
    'levels': {for (final entry in levels.entries) entry.key.name: entry.value},
    'breeders': breeders.toList(),
    'fish': fish.map((item) => item.toJson()).toList(),
    'corpses': corpses.map((item) => item.toJson()).toList(),
    'clutches': clutches.map((item) => item.toJson()).toList(),
  };
}
