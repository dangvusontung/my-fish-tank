import 'dart:math' as math;

import 'decor.dart';
import 'species.dart';
import 'species_catalog.dart';

export 'decor.dart';
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
  snails('Ốc ramshorn', 'Thêm 3 ốc tự rỉa xác cá, kể cả lúc vắng nhà.', 60),
  nursery(
    'Khu ươm',
    'Bể riêng có nước và mồi riêng. Cá lớn không săn được cá con ở đây.',
    160,
  ),
  bettaCups(
    'Ngăn betta',
    'Ngăn riêng cho betta trống thừa, khỏi đánh nhau.',
    90,
  );

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

/// Where a fish lives. Betta cups are dividers inside the main tank, so
/// they share its water and food.
enum Zone {
  main('Bể chính'),
  nursery('Khu ươm'),
  cups('Ngăn betta');

  const Zone(this.label);
  final String label;
}

Species _speciesById(String id, Map<String, Species>? definitions) =>
    definitions?[id] ??
    Species.builtInById[id] ??
    (throw FormatException('Unknown saved fish species $id'));

class Fish {
  Fish({
    required this.id,
    this._species = Species.guppy,
    required this.sex,
    required this.tail,
    required this.bornAt,
    required this.adultDay,
    required this.lifeDays,
    required this.vividness,
    this.isComet = false,
    this.zone = Zone.main,
    this.litter,
  });

  factory Fish.fromJson(
    Map<String, dynamic> json, {
    Map<String, Species>? definitions,
  }) => Fish(
    id: json['id'] as int,
    species: _speciesById(json['species'] as String? ?? 'guppy', definitions),
    sex: Sex.values.byName(json['sex'] as String),
    tail: Tail.values.byName(json['tail'] as String),
    bornAt: (json['bornAt'] as num).toDouble(),
    adultDay: json['adultDay'] as int,
    lifeDays: json['lifeDays'] as int,
    vividness: json['vividness'] as int,
    isComet: json['isComet'] as bool? ?? false,
    zone: Zone.values.byName(json['zone'] as String? ?? 'main'),
    litter: json['litter'] as int?,
  );

  final int id;
  Species _species;
  Species get species => _species;
  final Sex sex;
  final Tail tail;
  final double bornAt;
  final int adultDay;
  final int lifeDays;
  final int vividness;

  /// Legendary comet-tail guppy variant.
  final bool isComet;
  Zone zone;

  /// The [Litter] this fish was born in, if it was bred here.
  final int? litter;

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
    'zone': zone.name,
    'litter': ?litter,
  };
}

/// A dead fish lying on the floor. It fouls the water until it is scooped
/// out or snails have eaten all of it.
class Corpse {
  Corpse({
    required this.id,
    required this._species,
    required this.tail,
    required this.diedAt,
    this.remains = 1,
    this.zone = Zone.main,
  });

  factory Corpse.fromJson(
    Map<String, dynamic> json, {
    Map<String, Species>? definitions,
  }) => Corpse(
    id: json['id'] as int,
    species: _speciesById(json['species'] as String, definitions),
    tail: Tail.values.byName(json['tail'] as String),
    diedAt: (json['diedAt'] as num).toDouble(),
    remains: (json['remains'] as num).toDouble(),
    zone: Zone.values.byName(json['zone'] as String? ?? 'main'),
  );

  final int id;
  Species _species;
  Species get species => _species;
  final Tail tail;
  final double diedAt;
  final Zone zone;
  double remains;

  /// Horizontal resting place as a fraction of the tank width.
  double get x => .1 + (id * .6180339 % 1) * .8;

  Map<String, Object> toJson() => {
    'id': id,
    'species': species.name,
    'tail': tail.name,
    'diedAt': diedAt,
    'remains': remains,
    'zone': zone.name,
  };
}

/// Eggs from one spawning, hatching all at once at [hatchAt].
class Clutch {
  Clutch({
    required this.id,
    required this._species,
    required this.eggs,
    required this.hatchAt,
    required this.tails,
    required this.vividness,
    this.parents = const [],
  });

  factory Clutch.fromJson(
    Map<String, dynamic> json, {
    Map<String, Species>? definitions,
  }) => Clutch(
    id: json['id'] as int,
    species: _speciesById(json['species'] as String, definitions),
    eggs: json['eggs'] as int,
    hatchAt: (json['hatchAt'] as num).toDouble(),
    tails: [
      for (final tail in json['tails'] as List<dynamic>)
        Tail.values.byName(tail as String),
    ],
    vividness: (json['vividness'] as List<dynamic>).cast<int>(),
    parents: (json['parents'] as List<dynamic>? ?? const []).cast<int>(),
  );

  final int id;
  Species _species;
  Species get species => _species;
  final int eggs;
  final double hatchAt;

  /// Traits of the two parents, inherited by the fry.
  final List<Tail> tails;
  final List<int> vividness;
  final List<int> parents;

  Map<String, Object> toJson() => {
    'id': id,
    'species': species.name,
    'eggs': eggs,
    'parents': parents,
    'hatchAt': hatchAt,
    'tails': tails.map((tail) => tail.name).toList(),
    'vividness': vividness,
  };
}

/// One birth or spawning, kept for the breeding history and lot sales.
class Litter {
  Litter({
    required this.id,
    required this._species,
    required this.bornAt,
    required this.parents,
    required this.tails,
    required this.born,
    this.eggs,
    this.comets = 0,
  });

  factory Litter.fromJson(
    Map<String, dynamic> json, {
    Map<String, Species>? definitions,
  }) => Litter(
    id: json['id'] as int,
    species: _speciesById(json['species'] as String, definitions),
    bornAt: (json['bornAt'] as num).toDouble(),
    parents: (json['parents'] as List<dynamic>).cast<int>(),
    tails: [
      for (final tail in json['tails'] as List<dynamic>)
        Tail.values.byName(tail as String),
    ],
    born: json['born'] as int,
    eggs: json['eggs'] as int?,
    comets: json['comets'] as int? ?? 0,
  );

  final int id;
  Species _species;
  Species get species => _species;
  final double bornAt;
  final List<int> parents;
  final List<Tail> tails;
  final int born;

  /// Eggs laid, for egg layers. A clutch eaten before hatching has none born.
  final int? eggs;
  int comets;

  bool get lost => eggs != null && born == 0;

  Map<String, Object> toJson() => {
    'id': id,
    'species': species.name,
    'bornAt': bornAt,
    'parents': parents,
    'tails': tails.map((tail) => tail.name).toList(),
    'born': born,
    'eggs': ?eggs,
    'comets': comets,
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
  int graduated = 0;
  int housed = 0;
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
          graduated +
          housed +
          coins >
      0;
}

class Pond {
  Pond({SpeciesCatalog? catalog}) {
    if (catalog != null) applyCatalog(catalog);
  }

  factory Pond.starter({SpeciesCatalog? catalog}) {
    final pond = Pond(catalog: catalog);
    pond._addFish(age: 103, sex: Sex.male, tail: Tail.amber, vividness: 62);
    pond._addFish(age: 114, sex: Sex.female, tail: Tail.violet, vividness: 65);
    pond.breeders.addAll({1, 2});
    pond._addFish(age: 77, sex: Sex.male, tail: Tail.amber, vividness: 97);
    for (var i = 0; i < 4; i++) {
      pond._addFish(age: 80 + i * 3);
      pond._addFish(age: 22 + i * 8);
    }
    pond.nextLitter[pond._knownSpecies[Species.guppy.name]!] =
        4 * daySeconds.toDouble();
    return pond;
  }

  factory Pond.fromJson(Map<String, dynamic> json, {SpeciesCatalog? catalog}) {
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
    final definitions = pond._knownSpecies;
    for (final value
        in json['speciesDefinitions'] as List<dynamic>? ?? const []) {
      final species = Species.fromJson(value as Map<String, dynamic>);
      definitions[species.name] = species;
    }
    if (catalog != null) {
      pond._catalog = catalog;
      definitions.addAll(catalog.byId);
    }
    pond.raritySeed = json['raritySeed'] as int? ?? pond.raritySeed;
    final levels = json['levels'] as Map<String, dynamic>;
    for (final equipment in Equipment.values) {
      pond.levels[equipment] = levels[equipment.name] as int? ?? 0;
    }
    pond.breeders.addAll((json['breeders'] as List<dynamic>).cast<int>());
    pond.fish.addAll(
      (json['fish'] as List<dynamic>).map(
        (value) => Fish.fromJson(
          value as Map<String, dynamic>,
          definitions: definitions,
        ),
      ),
    );
    if (version == 1) {
      pond.nextLitter[pond._knownSpecies[Species.guppy.name]!] =
          (json['nextLitter'] as num).toDouble();
      for (var i = json['dead'] as int; i > 0; i--) {
        pond.corpses.add(
          Corpse(
            id: pond.nextId++,
            species: definitions[Species.guppy.name]!,
            tail: Tail.amber,
            diedAt: pond.time,
          ),
        );
      }
      return pond;
    }
    pond.feederMode = FeederMode.values.byName(json['feederMode'] as String);
    pond
      ..nurseryWater = (json['nurseryWater'] as num? ?? 100).toDouble()
      ..nurserySatiety = (json['nurserySatiety'] as num? ?? 80).toDouble()
      ..nextNurseryFeed = (json['nextNurseryFeed'] as num? ?? 0).toDouble()
      ..autoNursery = json['autoNursery'] as bool? ?? true
      ..nextLitterId = json['nextLitterId'] as int? ?? 1
      ..nextDecorId = json['nextDecorId'] as int? ?? 1;
    pond.decor.addAll(
      (json['decor'] as List<dynamic>? ?? const []).map(
        (value) => Decor.fromJson(value as Map<String, dynamic>),
      ),
    );
    pond.litters.addAll(
      (json['litters'] as List<dynamic>? ?? const []).map(
        (value) => Litter.fromJson(
          value as Map<String, dynamic>,
          definitions: definitions,
        ),
      ),
    );
    for (final entry in (json['nextLitter'] as Map<String, dynamic>).entries) {
      pond.nextLitter[_speciesById(entry.key, definitions)] =
          (entry.value as num).toDouble();
    }
    for (final entry in (json['pairSpawns'] as Map<String, dynamic>).entries) {
      pond.pairSpawns[_speciesById(entry.key, definitions)] =
          entry.value as int;
    }
    pond.corpses.addAll(
      (json['corpses'] as List<dynamic>).map(
        (value) => Corpse.fromJson(
          value as Map<String, dynamic>,
          definitions: definitions,
        ),
      ),
    );
    pond.clutches.addAll(
      (json['clutches'] as List<dynamic>).map(
        (value) => Clutch.fromJson(
          value as Map<String, dynamic>,
          definitions: definitions,
        ),
      ),
    );
    return pond;
  }

  static const daySeconds = 120;
  static const maxOffline = Duration(hours: 8);
  static const waterChangeCost = 12;
  static const fryDays = 8;
  static const nurseryRoomPerLevel = 60;
  static const cupsPerLevel = 2;
  static const keptLitters = 40;

  SpeciesCatalog _catalog = SpeciesCatalog.builtIn;
  final _knownSpecies = Map<String, Species>.of(Species.builtInById);

  SpeciesCatalog get catalog => _catalog;

  void applyCatalog(SpeciesCatalog catalog) {
    _catalog = catalog;
    _knownSpecies.addAll(catalog.byId);
    for (final item in fish) {
      item._species = _knownSpecies[item.species.name] ?? item.species;
    }
    for (final item in corpses) {
      item._species = _knownSpecies[item.species.name] ?? item.species;
    }
    for (final item in clutches) {
      item._species = _knownSpecies[item.species.name] ?? item.species;
    }
    for (final item in litters) {
      item._species = _knownSpecies[item.species.name] ?? item.species;
    }
  }

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
    Equipment.nursery: 0,
    Equipment.bettaCups: 0,
  };
  final List<Litter> litters = [];
  final List<Decor> decor = [];
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
  double nurseryWater = 100;
  double nurserySatiety = 80;
  double nextNurseryFeed = 0;
  int nextLitterId = 1;
  int nextDecorId = 1;

  /// Whether newborns go straight to the nursery while it has room.
  bool autoNursery = true;

  /// When the feeder last dropped food into the main tank. Not saved; the
  /// tank uses it to show the drop.
  double lastAutoFeed = -1;

  int get day => time ~/ daySeconds + 1;
  int get adultCount => fish.where((item) => item.isAdult(time)).length;
  int get juvenileCount => fish.length - adultCount;
  int get dead => corpses.length;
  int get sheltered =>
      levels[Equipment.javaMoss]! * 7 +
      placedDecor.fold(0, (total, item) => total + item.kind.shelter);

  Iterable<Decor> get placedDecor => decor.where((item) => item.placed);

  /// Placed pieces of [effect] that [species] likes.
  int _liked(Species species, DecorEffect effect) => placedDecor
      .where(
        (item) =>
            item.kind.effect == effect &&
            item.kind.likedBy.contains(species.name),
      )
      .length;

  /// How many betta males can each hold a territory in the main tank.
  int get bettaTerritories => 1 + _liked(Species.betta, DecorEffect.territory);

  static const comfortPerDecor = 8;
  static const comfortBonus = .15;
  int get snails => levels[Equipment.snails]! * 3;
  int get capacity => 26 + levels[Equipment.storage]! * 20;
  int get nurseryCapacity => levels[Equipment.nursery]! * nurseryRoomPerLevel;
  int get cups => levels[Equipment.bettaCups]! * cupsPerLevel;
  bool get hasNursery => nurseryCapacity > 0;
  int inZone(Zone zone) => fish.where((item) => item.zone == zone).length;
  int get nurseryRoom => math.max(0, nurseryCapacity - inZone(Zone.nursery));
  int get freeCups => math.max(0, cups - inZone(Zone.cups));
  double waterOf(Zone zone) => zone == Zone.nursery ? nurseryWater : water;
  double satietyOf(Zone zone) =>
      zone == Zone.nursery ? nurserySatiety : satiety;

  /// Fish fed from [zone]'s food. Cups share the main tank's.
  bool _feedsFrom(Fish item, Zone zone) =>
      (item.zone == Zone.nursery) == (zone == Zone.nursery);
  int get eggCount => clutches.fold(0, (total, clutch) => total + clutch.eggs);
  double get income => _income(time);

  /// Built-in species retain their original tick order across catalog updates.
  Iterable<Species> get scheduledSpecies sync* {
    for (final species in Species.builtIn) {
      if (nextLitter.containsKey(species)) yield _knownSpecies[species.name]!;
    }
    for (final species in nextLitter.keys) {
      if (!Species.builtInById.containsKey(species.name)) {
        yield _knownSpecies[species.name] ?? species;
      }
    }
  }

  /// Species with at least one living fish in the tank.
  Set<Species> get ownedSpecies => {for (final item in fish) item.species};

  int count(Species species) =>
      fish.where((item) => item.species == species).length;

  int adults(Species species, {Zone? zone}) => fish
      .where(
        (item) =>
            item.species == species &&
            (zone == null || item.zone == zone) &&
            item.isAdult(time),
      )
      .length;

  List<Fish> pairOf(Species species) => fish
      .where((item) => item.species == species && breeders.contains(item.id))
      .toList();

  int? daysToLitter(Species species) {
    final due = nextLitter[species];
    if (due == null || pairOf(species).length < 2) return null;
    return math.max(1, ((due - time) / daySeconds).ceil());
  }

  /// Adult male bettas without a territory, which fight instead of earning.
  int get rivalBettas => math.max(
    0,
    fish
            .where(
              (item) =>
                  item.species == Species.betta &&
                  item.sex == Sex.male &&
                  item.zone == Zone.main &&
                  item.isAdult(time),
            )
            .length -
        bettaTerritories,
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
    final schoolAdults = <Species, int>{};
    for (final item in fish) {
      if (item.species.schoolSize > 0 &&
          item.zone == Zone.main &&
          item.isAdult(at)) {
        schoolAdults.update(
          item.species,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
    var bettaMales = 0;
    final territories = bettaTerritories;
    var main = 0.0;
    var nursery = 0.0;
    for (final item in fish) {
      final species = item.species;
      var value = species.youngIncome;
      if (item.isAdult(at)) {
        value = species.adultIncome;
        if (species.schoolSize > 0) {
          value *= (schoolAdults[species] ?? 0) >= species.schoolSize
              ? 1.35
              : .7;
        }
        // Each territory holds one male; males in cups earn in peace.
        if (species == Species.betta &&
            item.sex == Sex.male &&
            item.zone == Zone.main &&
            bettaMales++ >= territories) {
          value = 0;
        }
      }
      if (item.zone == Zone.nursery) {
        nursery += value;
      } else {
        main += value;
      }
    }
    main += _comfortIncome(at);
    double health(double food, double clean) =>
        (.30 + .70 * food / 100) * (.28 + .72 * clean / 100);
    return main * health(satiety, water) +
        nursery * health(nurserySatiety, nurseryWater);
  }

  /// Extra income from adults resting near decorations they like.
  double _comfortIncome(double at) {
    final kinds = {
      for (final item in placedDecor)
        if (item.kind.effect == DecorEffect.comfort) item.kind,
    };
    if (kinds.isEmpty) return 0;
    final adults = <Species, int>{};
    for (final item in fish) {
      if (item.zone == Zone.main && item.isAdult(at)) {
        adults.update(item.species, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    var bonus = 0.0;
    for (final MapEntry(key: species, value: count) in adults.entries) {
      final room = _liked(species, DecorEffect.comfort) * comfortPerDecor;
      bonus += math.min(count, room) * species.adultIncome * comfortBonus;
    }
    return bonus;
  }

  /// Share of [species]' eggs that hatch, after moss and spawning decor.
  double hatchRate(Species species) {
    var rate = species == Species.corydoras
        ? math.min(.8, species.hatchRate + levels[Equipment.javaMoss]! * .06)
        : species.hatchRate;
    final spawning = _liked(species, DecorEffect.spawning);
    if (spawning > 0) rate += math.min(.2, spawning * .1);
    return math.min(.95, rate);
  }

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
    Zone zone = Zone.main,
    int? litter,
  }) {
    species = _knownSpecies[species.name] ?? species;
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
        zone: zone,
        litter: litter,
      ),
    );
  }

  int _recordLitter(
    Species species,
    List<int> parents,
    List<Tail> tails, {
    required int born,
    int? eggs,
    int comets = 0,
  }) {
    final id = nextLitterId++;
    litters.add(
      Litter(
        id: id,
        species: species,
        bornAt: time,
        parents: parents,
        tails: tails,
        born: born,
        eggs: eggs,
        comets: comets,
      ),
    );
    if (litters.length > keptLitters) litters.removeAt(0);
    return id;
  }

  Litter? litterById(int? id) =>
      litters.where((litter) => litter.id == id).firstOrNull;

  int alive(int litterId) =>
      fish.where((item) => item.litter == litterId).length;

  void _bury(Fish item) {
    if (breeders.remove(item.id)) pairSpawns.remove(item.species);
    corpses.add(
      Corpse(
        id: item.id,
        species: item.species,
        tail: item.tail,
        diedAt: time,
        zone: item.zone == Zone.nursery ? Zone.nursery : Zone.main,
      ),
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
    var nurseryAdultLoad = 0.0;
    var nurseryYoungLoad = 0.0;
    var predators = 0.0;
    for (final item in fish) {
      final adult = item.isAdult(before);
      final load = item.species.load;
      if (item.zone == Zone.nursery) {
        if (adult) {
          nurseryAdultLoad += load;
        } else {
          nurseryYoungLoad += load;
        }
      } else if (adult) {
        adultLoad += load;
        if (item.zone == Zone.main) predators += item.species.predation;
      } else {
        youngLoad += load;
      }
    }
    time += step;
    if (adultLoad + youngLoad > 0) {
      satiety = math.max(
        0,
        satiety - step * (.0029 + adultLoad * .00024 + youngLoad * .00008),
      );
    }
    if (nurseryAdultLoad + nurseryYoungLoad > 0) {
      nurserySatiety = math.max(
        0,
        nurserySatiety -
            step *
                (.0029 + nurseryAdultLoad * .00024 + nurseryYoungLoad * .00008),
      );
    }
    final feeder = levels[Equipment.feeder]!;
    if (feeder > 0 &&
        stock > 0 &&
        satiety < feederMode.threshold &&
        time >= nextFeed) {
      feed();
      stock--;
      lastAutoFeed = time;
      nextFeed = time + feedInterval(feeder);
    }
    if (feeder > 0 &&
        stock > 0 &&
        nurseryAdultLoad + nurseryYoungLoad > 0 &&
        nurserySatiety < feederMode.threshold &&
        time >= nextNurseryFeed) {
      feed(Zone.nursery);
      stock--;
      nextNurseryFeed = time + feedInterval(feeder);
    }
    final cleanRate = .0037 + levels[Equipment.filter]! * .009;
    final nurseryCorpses = corpses
        .where((corpse) => corpse.zone == Zone.nursery)
        .length;
    final wasteRate =
        adultLoad * .00031 +
        youngLoad * .00013 +
        (corpses.length - nurseryCorpses) * .0048;
    water = (water + (cleanRate - wasteRate) * step).clamp(0, 100).toDouble();
    if (hasNursery) {
      final nurseryClean = .006 + levels[Equipment.nursery]! * .004;
      final nurseryWaste =
          nurseryAdultLoad * .00031 +
          nurseryYoungLoad * .00013 +
          nurseryCorpses * .0048;
      nurseryWater = (nurseryWater + (nurseryClean - nurseryWaste) * step)
          .clamp(0, 100)
          .toDouble();
    }
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
      if (!item.isAdult(before) && item.isAdult(time)) {
        report.grown++;
        // Grown fish leave the nursery for the main tank.
        if (item.zone == Zone.nursery) {
          item.zone = Zone.main;
          report.graduated++;
        }
      }
      return false;
    });

    _cull(step, report);
    _house(report);
    _fight(step, report);
    for (final species in scheduledSpecies) {
      _spawn(species, report);
    }
    _hatch(report);
    _hunt(step, predators, report);
  }

  /// Newborns go to the nursery while [autoNursery] is on and it has room.
  Zone Function() _cradle() {
    var room = autoNursery ? nurseryRoom : 0;
    return () => room-- > 0 ? Zone.nursery : Zone.main;
  }

  /// Rival betta males move into free cups before they can fight.
  void _house(PondReport report) {
    var free = freeCups;
    if (free == 0) return;
    final males = fish
        .where(
          (item) =>
              item.species == Species.betta &&
              item.sex == Sex.male &&
              item.zone == Zone.main &&
              item.isAdult(time),
        )
        .toList();
    final holders = _territoryHolders(males);
    for (final rival in males) {
      if (free == 0) break;
      if (holders.contains(rival)) continue;
      rival.zone = Zone.cups;
      free--;
      report.housed++;
    }
  }

  /// The males that hold a territory: the breeding male first, then others
  /// in tank order, one per territory.
  Set<Fish> _territoryHolders(List<Fish> males) {
    if (males.isEmpty) return {};
    final breeder = males.firstWhere(
      (item) => breeders.contains(item.id),
      orElse: () => males.first,
    );
    return {
      breeder,
      ...males.where((item) => item != breeder),
    }.take(bettaTerritories).toSet();
  }

  /// Hatched fry die off at their species' rate, faster when the pond is
  /// hungry or dirty.
  void _cull(double step, PondReport report) {
    double chance(double food, double clean) =>
        step /
        daySeconds *
        (1 + (1 - food / 100) + (clean < 50 ? (50 - clean) / 50 : 0)) *
        100000;
    final main = chance(satiety, water);
    // The nursery is calmer, so fry there die off more slowly.
    final nursery = chance(nurserySatiety, nurseryWater) * .6;
    fish.removeWhere((item) {
      final fryLoss = item.species.fryLoss;
      if (fryLoss == 0 || item.age(time) >= fryDays) return false;
      final odds = item.zone == Zone.nursery ? nursery : main;
      if (_random(100000) >= fryLoss * odds) return false;
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
              item.zone == Zone.main &&
              item.isAdult(time),
        )
        .toList();
    // Every male without a territory risks a fatal fight.
    final holders = _territoryHolders(males);
    for (final rival in males) {
      if (holders.contains(rival)) continue;
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
        water >= species.spawnWater &&
        parents.every(
          (parent) => parent.isAdult(time) && parent.zone == Zone.main,
        );
    if (!ready) {
      nextLitter[species] = time + daySeconds;
      return;
    }
    final count = _between(species.clutch);
    final parentIds = [for (final parent in parents) parent.id];
    final parentTails = [for (final parent in parents) parent.tail];
    if (species.brood == Brood.live) {
      final cometParents = parents.where((parent) => parent.isComet).length;
      final litter = _recordLitter(
        species,
        parentIds,
        parentTails,
        born: count,
      );
      final cradle = _cradle();
      var comets = 0;
      for (var i = 0; i < count; i++) {
        final parent = parents[_random(parents.length)];
        final comet = species == Species.guppy && _rollComet(cometParents);
        _addFish(
          species: species,
          tail: _random(100) < 77 ? parent.tail : null,
          vividness: (parent.vividness + _random(31) - 15).clamp(28, 100),
          isComet: comet,
          zone: cradle(),
          litter: litter,
        );
        if (comet) comets++;
      }
      litterById(litter)?.comets = comets;
      report.cometsBorn += comets;
      report.born += count;
    } else {
      final spawns = pairSpawns[species] ?? 0;
      pairSpawns[species] = spawns + 1;
      if (species == Species.angelfish && spawns == 0 && _random(2) == 0) {
        _recordLitter(species, parentIds, parentTails, born: 0, eggs: count);
        report.clutchesLost++;
      } else {
        clutches.add(
          Clutch(
            id: nextId++,
            species: species,
            eggs: count,
            hatchAt: time + species.incubation * daySeconds,
            tails: parentTails,
            vividness: [for (final parent in parents) parent.vividness],
            parents: parentIds,
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
      final hatched = (clutch.eggs * hatchRate(clutch.species) * variance)
          .round()
          .clamp(0, clutch.eggs);
      final litter = _recordLitter(
        clutch.species,
        clutch.parents,
        clutch.tails,
        born: hatched,
        eggs: clutch.eggs,
      );
      final cradle = _cradle();
      for (var i = 0; i < hatched; i++) {
        final parent = _random(2);
        _addFish(
          species: clutch.species,
          tail: _random(100) < 77 ? clutch.tails[parent] : null,
          vividness: (clutch.vividness[parent] + _random(31) - 15).clamp(
            28,
            100,
          ),
          zone: cradle(),
          litter: litter,
        );
      }
      report.hatched += hatched;
    }
  }

  void _hunt(double step, double predators, PondReport report) {
    final fry = fish
        .where((item) => item.zone == Zone.main && item.age(time) < fryDays)
        .toList();
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

  /// Drops one portion of food into [zone]. Returns whether some of it was
  /// left over to foul the water.
  bool feed([Zone zone = Zone.main]) {
    final eaters = fish.where((item) => _feedsFrom(item, zone)).toList();
    if (eaters.isEmpty) return false;
    final portion = 24 / (1 + eaters.length / 55);
    if (zone == Zone.nursery) {
      final excess = math.max(0.0, nurserySatiety + portion - 100);
      nurserySatiety = math.min(100, nurserySatiety + portion);
      nurseryWater = math.max(0, nurseryWater - .34 * excess);
      return excess > 2;
    }
    final excess = math.max(0.0, satiety + portion - 100);
    // Corydoras pick up leftovers before they rot.
    final scavengers = eaters
        .where(
          (item) => item.species == Species.corydoras && item.isAdult(time),
        )
        .length;
    final leftovers = math.max(.5, 1 - .04 * scavengers);
    satiety = math.min(100, satiety + portion);
    water = math.max(0, water - .34 * excess * leftovers);
    return excess > 2;
  }

  int upgradeCost(Equipment equipment) =>
      (equipment.price * math.pow(1.6, levels[equipment]!)).round();

  /// Real seconds the feeder rests between drops at [level].
  static int feedInterval(int level) => math.max(55, 270 - 35 * level);

  /// The feeder cannot rest less than 55 seconds, which it reaches here.
  static const feederMaxLevel = 7;

  bool isMaxed(Equipment equipment) =>
      equipment == Equipment.feeder && levels[equipment]! >= feederMaxLevel;

  bool canUpgrade(Equipment equipment) =>
      !isMaxed(equipment) &&
      coins >= upgradeCost(equipment) &&
      (equipment != Equipment.storage || levels[Equipment.feeder]! > 0);

  /// What [equipment] does at [level], in the units the player sees.
  String effectAt(Equipment equipment, int level) {
    String duration(int seconds) {
      final minutes = seconds ~/ 60;
      final rest = seconds % 60;
      if (minutes == 0) return '$rest giây';
      return rest == 0 ? '$minutes phút' : '$minutes phút $rest giây';
    }

    String perMinute(double value) =>
        value.toStringAsFixed(2).replaceAll('.', ',');

    return switch (equipment) {
      Equipment.feeder =>
        level == 0 ? 'chưa lắp' : 'nghỉ ${duration(feedInterval(level))}',
      Equipment.storage => '${26 + level * 20} phần mồi',
      Equipment.filter => '${perMinute(level * .009 * 60)} điểm nước/phút',
      Equipment.javaMoss => '${level * 7} chỗ trú cá non',
      Equipment.snails => '${level * 3} ốc',
      Equipment.nursery =>
        level == 0 ? 'chưa có' : '${level * nurseryRoomPerLevel} chỗ cá con',
      Equipment.bettaCups => '${level * cupsPerLevel} ngăn',
    };
  }

  /// Why one more level of [equipment] would not change income soon, when
  /// the pond's state explains it.
  String? flatReason(Equipment equipment) {
    final fry = fish
        .where((item) => item.zone == Zone.main && item.age(time) < fryDays)
        .length;
    return switch (equipment) {
      Equipment.feeder when levels[equipment] == 0 => null,
      Equipment.feeder when stock == 0 =>
        'Kho mồi đã hết, nạp thêm để máy rải tiếp',
      Equipment.feeder when satiety >= feederMode.threshold =>
        'Cá đang đủ no, máy chưa cần rải nhanh hơn',
      Equipment.storage => 'Nạp thêm mồi để dùng sức chứa mới',
      Equipment.filter when water >= 95 => 'Bộ lọc hiện tại đã đủ cho đàn này',
      Equipment.javaMoss when fry == 0 => 'Chưa có cá con cần chỗ trú',
      Equipment.javaMoss when fry <= sheltered =>
        'Rêu đã đủ chỗ cho $fry cá con',
      Equipment.snails when dead == 0 => 'Chưa có xác cá để dọn',
      Equipment.nursery when levels[equipment] == 0 =>
        'Giữ lứa sau an toàn khỏi cá lớn',
      Equipment.nursery when nurseryRoom > 0 =>
        'Khu ươm còn $nurseryRoom chỗ trống',
      Equipment.bettaCups when rivalBettas == 0 =>
        'Chưa có betta trống thừa cần ngăn riêng',
      _ => null,
    };
  }

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

  Pond copy() =>
      Pond.fromJson(toJson(), catalog: _catalog.revision > 0 ? _catalog : null);

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

  void changeWater([Zone zone = Zone.main]) {
    if (coins < waterChangeCost || waterOf(zone) >= 99) return;
    coins -= waterChangeCost;
    if (zone == Zone.nursery) {
      nurseryWater = math.min(100, nurseryWater + 30);
    } else {
      water = math.min(100, water + 30);
    }
  }

  /// Where [item] may move to, given room in each zone.
  List<Zone> movesFor(Fish item) => [
    for (final zone in Zone.values)
      if (zone != item.zone &&
          switch (zone) {
            Zone.main => true,
            Zone.nursery => nurseryRoom > 0,
            Zone.cups => item.species == Species.betta && freeCups > 0,
          })
        zone,
  ];

  /// Moves fish [id] into [zone]. A breeder that leaves the main tank stops
  /// breeding.
  bool moveFish(int id, Zone zone) {
    final item = fish.where((value) => value.id == id).firstOrNull;
    if (item == null || !movesFor(item).contains(zone)) return false;
    item.zone = zone;
    if (zone != Zone.main && breeders.remove(id)) {
      pairSpawns.remove(item.species);
    }
    return true;
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
    final listing = _catalog.byId[species.name];
    if (listing == null || !listing.available || coins < listing.pairCost) {
      return false;
    }
    species = _knownSpecies[listing.name]!;
    coins -= listing.pairCost;
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

  bool buyDecor(DecorKind kind, {double x = .5, double y = .86}) {
    if (coins < kind.price) return false;
    coins -= kind.price;
    decor.add(Decor(id: nextDecorId++, kind: kind)..moveTo(x, y));
    return true;
  }

  /// Puts a stored piece back in the tank, or stores a placed one.
  void setPlaced(int id, bool placed) {
    for (final item in decor) {
      if (item.id == id) item.placed = placed;
    }
  }

  /// Sells a piece back for half its price.
  int sellDecor(int id) {
    final item = decor.where((value) => value.id == id).firstOrNull;
    if (item == null) return 0;
    decor.remove(item);
    coins += item.kind.resale;
    return item.kind.resale;
  }

  /// What [item] sells for now: full price grown, less while growing, and
  /// nothing while it is still a fry.
  int priceOf(Fish item) {
    if (item.isAdult(time)) return item.price;
    if (item.age(time) < fryDays) return 0;
    return (item.price * (.3 + .5 * item.growth(time))).round();
  }

  /// Fish from [litter] that can be sold now: past the fry stage and not
  /// kept for breeding. A null [litter] means fish of unknown lineage.
  List<Fish> sellableIn(int? litter) => fish
      .where(
        (item) =>
            item.litter == litter &&
            !breeders.contains(item.id) &&
            item.age(time) >= fryDays,
      )
      .toList();

  /// Litters with fish for sale, newest first; unknown lineage last.
  List<int?> get litterLots {
    final ids = <int?>{};
    for (final item in fish) {
      if (breeders.contains(item.id) || item.age(time) < fryDays) continue;
      ids.add(item.litter);
    }
    return ids.toList()..sort((a, b) {
      if (a == null) return 1;
      if (b == null) return -1;
      return b.compareTo(a);
    });
  }

  (int, int) sellLitter(int? litter) {
    final sale = sellableIn(litter);
    final total = sale.fold(0, (sum, item) => sum + priceOf(item));
    final sold = sale.map((item) => item.id).toSet();
    fish.removeWhere((item) => sold.contains(item.id));
    coins += total;
    return (sale.length, total);
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

  List<Map<String, Object>> _savedDefinitions() {
    final used = {
      for (final item in fish) item.species,
      for (final item in corpses) item.species,
      for (final item in clutches) item.species,
      for (final item in litters) item.species,
      ...nextLitter.keys,
      ...pairSpawns.keys,
    };
    return [
      for (final species in used)
        if ((_knownSpecies[species.name] ?? species) case final definition
            when !identical(definition, Species.builtInById[species.name]))
          definition.toJson(),
    ];
  }

  Map<String, Object> toJson() => {
    'version': 2,
    'speciesDefinitions': _savedDefinitions(),
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
    'nurseryWater': nurseryWater,
    'nurserySatiety': nurserySatiety,
    'nextNurseryFeed': nextNurseryFeed,
    'autoNursery': autoNursery,
    'nextLitterId': nextLitterId,
    'litters': litters.map((item) => item.toJson()).toList(),
    'nextDecorId': nextDecorId,
    'decor': decor.map((item) => item.toJson()).toList(),
    'levels': {for (final entry in levels.entries) entry.key.name: entry.value},
    'breeders': breeders.toList(),
    'fish': fish.map((item) => item.toJson()).toList(),
    'corpses': corpses.map((item) => item.toJson()).toList(),
    'clutches': clutches.map((item) => item.toJson()).toList(),
  };
}
