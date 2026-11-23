import 'dart:math' as math;

enum Tail {
  amber('đuôi cam'),
  violet('đuôi tím'),
  rose('đuôi hồng');

  const Tail(this.label);
  final String label;
}

enum Sex { male, female }

enum Equipment {
  feeder('Máy cho ăn', 'Tự cho cá ăn khi đói.', 115),
  filter('Bộ lọc', 'Giảm chất thải trong hồ.', 95),
  javaMoss('Rêu Java', 'Cho cá con thêm chỗ trú.', 75);

  const Equipment(this.label, this.detail, this.price);
  final String label;
  final String detail;
  final int price;
}

class Fish {
  const Fish({
    required this.id,
    required this.sex,
    required this.tail,
    required this.bornAt,
    required this.adultDay,
    required this.lifeDays,
    required this.vividness,
  });

  factory Fish.fromJson(Map<String, dynamic> json) => Fish(
    id: json['id'] as int,
    sex: Sex.values.byName(json['sex'] as String),
    tail: Tail.values.byName(json['tail'] as String),
    bornAt: (json['bornAt'] as num).toDouble(),
    adultDay: json['adultDay'] as int,
    lifeDays: json['lifeDays'] as int,
    vividness: json['vividness'] as int,
  );

  final int id;
  final Sex sex;
  final Tail tail;
  final double bornAt;
  final int adultDay;
  final int lifeDays;
  final int vividness;

  double age(double time) => (time - bornAt) / Pond.daySeconds;
  double growth(double time) => (age(time) / adultDay).clamp(0, 1).toDouble();
  bool isAdult(double time) => age(time) >= adultDay;
  int get price => 20 + vividness ~/ 3;

  Map<String, Object> toJson() => {
    'id': id,
    'sex': sex.name,
    'tail': tail.name,
    'bornAt': bornAt,
    'adultDay': adultDay,
    'lifeDays': lifeDays,
    'vividness': vividness,
  };
}

class PondReport {
  int born = 0;
  int grown = 0;
  int eaten = 0;
  int died = 0;
  int coins = 0;

  bool get hasEvents => born + grown + eaten + died + coins > 0;
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
    return pond;
  }

  factory Pond.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) throw const FormatException('Save version');
    final pond = Pond()
      ..time = (json['time'] as num).toDouble()
      ..coins = (json['coins'] as num).toDouble()
      ..satiety = (json['satiety'] as num).toDouble()
      ..water = (json['water'] as num).toDouble()
      ..nextLitter = (json['nextLitter'] as num).toDouble()
      ..nextFeed = (json['nextFeed'] as num).toDouble()
      ..predation = (json['predation'] as num).toDouble()
      ..stock = json['stock'] as int
      ..dead = json['dead'] as int
      ..nextId = json['nextId'] as int
      ..seed = json['seed'] as int
      ..preference = Tail.values.byName(json['preference'] as String);
    final levels = json['levels'] as Map<String, dynamic>;
    for (final equipment in Equipment.values) {
      pond.levels[equipment] = levels[equipment.name] as int;
    }
    pond.breeders.addAll((json['breeders'] as List<dynamic>).cast<int>());
    pond.fish.addAll(
      (json['fish'] as List<dynamic>).map(
        (value) => Fish.fromJson(value as Map<String, dynamic>),
      ),
    );
    return pond;
  }

  static const daySeconds = 300;
  static const maxOffline = Duration(hours: 8);
  static const refillCost = 20;
  static const waterChangeCost = 12;

  final List<Fish> fish = [];
  final Set<int> breeders = {};
  final Map<Equipment, int> levels = {
    Equipment.feeder: 0,
    Equipment.filter: 1,
    Equipment.javaMoss: 1,
  };

  double time = 0;
  double coins = 180;
  double satiety = 72;
  double water = 94;
  double nextLitter = 4 * daySeconds.toDouble();
  double nextFeed = 0;
  double predation = 0;
  int stock = 0;
  int dead = 0;
  int nextId = 1;
  int seed = 443016;
  Tail preference = Tail.amber;

  int get day => time ~/ daySeconds + 1;
  int get adultCount => fish.where((item) => item.isAdult(time)).length;
  int get juvenileCount => fish.length - adultCount;
  int get sheltered => levels[Equipment.javaMoss]! * 7;
  int get daysToLitter =>
      math.max(1, ((nextLitter - time) / daySeconds).ceil());
  double get income => _income(adultCount);

  List<Fish> get forSale => fish
      .where((item) => item.isAdult(time) && !breeders.contains(item.id))
      .toList();
  int get saleValue => forSale.fold(0, (total, fish) => total + fish.price);

  Fish? get candidate {
    Fish? best;
    for (final item in forSale) {
      if (item.tail != preference || item.age(time) > 220) continue;
      final current = fish
          .where(
            (parent) => breeders.contains(parent.id) && parent.sex == item.sex,
          )
          .firstOrNull;
      if (current != null &&
          current.tail == preference &&
          _rank(item) <= _rank(current) + 7) {
        continue;
      }
      if (best == null || _rank(item) > _rank(best)) best = item;
    }
    return best;
  }

  double _rank(Fish item) => item.vividness - .16 * item.age(time);

  double _income(int adults) =>
      (adults * 1.32 + (fish.length - adults) * .28) *
      (.30 + .70 * satiety / 100) *
      (.28 + .72 * water / 100);

  int _random(int upperBound) {
    seed = (1664525 * seed + 1013904223) & 0xffffffff;
    return (seed >> 8) % upperBound;
  }

  void _addFish({int age = 0, Sex? sex, Tail? tail, int? vividness}) {
    fish.add(
      Fish(
        id: nextId++,
        sex: sex ?? Sex.values[_random(Sex.values.length)],
        tail: tail ?? Tail.values[_random(Tail.values.length)],
        bornAt: time - age * daySeconds,
        adultDay: 54 + _random(15),
        lifeDays: 395 + _random(150),
        vividness: vividness ?? 42 + _random(45),
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
    final adults = adultCount;
    final young = fish.length - adults;
    time += step;
    if (fish.isNotEmpty) {
      satiety = math.max(
        0,
        satiety - step * (.0029 + adults * .00024 + young * .00008),
      );
    }
    final feeder = levels[Equipment.feeder]!;
    if (feeder > 0 && stock > 0 && satiety < 70 && time >= nextFeed) {
      feed();
      stock--;
      nextFeed = time + math.max(55, 270 - 35 * feeder);
    }
    final cleanRate = .0037 + levels[Equipment.filter]! * .009;
    final wasteRate = adults * .00031 + young * .00013 + dead * .0048;
    water = (water + (cleanRate - wasteRate) * step).clamp(0, 100).toDouble();
    coins += _income(adults) * step / 60;

    fish.removeWhere((item) {
      if (item.age(time) >= item.lifeDays) {
        breeders.remove(item.id);
        dead++;
        report.died++;
        return true;
      }
      if (!item.isAdult(before) && item.isAdult(time)) report.grown++;
      return false;
    });

    if (breeders.length == 2 && time >= nextLitter) {
      if (satiety >= 25 && water >= 50) {
        final parents = fish
            .where((item) => breeders.contains(item.id))
            .toList();
        final count = 20 + _random(21);
        for (var i = 0; i < count; i++) {
          final parent = parents[_random(parents.length)];
          _addFish(
            tail: _random(100) < 77 ? parent.tail : null,
            vividness: (parent.vividness + _random(31) - 15).clamp(28, 100),
          );
        }
        report.born += count;
        nextLitter = time + (25 + _random(11)) * daySeconds;
      } else {
        nextLitter = time + daySeconds;
      }
    }

    final fry = fish.where((item) => item.age(time) < 8).toList();
    final exposed = math.max(0, fry.length - sheltered);
    if (exposed == 0 || adults == 0) {
      predation = 0;
      return;
    }
    predation += exposed * math.min(adults, 40) * step * .000012;
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
    satiety = math.min(100, satiety + portion);
    water = math.max(0, water - .34 * excess);
    return excess > 2;
  }

  int upgradeCost(Equipment equipment) =>
      (equipment.price * math.pow(1.6, levels[equipment]!)).round();

  bool upgrade(Equipment equipment) {
    final cost = upgradeCost(equipment);
    if (coins < cost) return false;
    coins -= cost;
    if (equipment == Equipment.feeder && levels[equipment] == 0) stock = 26;
    levels[equipment] = levels[equipment]! + 1;
    return true;
  }

  void refill() {
    if (coins < refillCost || levels[Equipment.feeder] == 0) return;
    coins -= refillCost;
    stock += 28;
  }

  void changeWater() {
    if (coins < waterChangeCost || water >= 99) return;
    coins -= waterChangeCost;
    water = math.min(100, water + 30);
  }

  void repairBreeders() {
    if (breeders.length == 2) return;
    for (final sex in Sex.values) {
      if (fish.any((item) => item.sex == sex && breeders.contains(item.id))) {
        continue;
      }
      var replacement = forSale.where((item) => item.sex == sex).firstOrNull;
      if (replacement == null) {
        _addFish(age: 84, sex: sex);
        replacement = fish.last;
      }
      breeders.add(replacement.id);
    }
    nextLitter = time + 4 * daySeconds;
  }

  (int, int) sell({required bool keepCandidate}) {
    final sale = forSale;
    if (keepCandidate) {
      final selected = candidate;
      if (selected == null) return (0, 0);
      final old = fish
          .where(
            (item) => breeders.contains(item.id) && item.sex == selected.sex,
          )
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
    'version': 1,
    'time': time,
    'coins': coins,
    'satiety': satiety,
    'water': water,
    'nextLitter': nextLitter,
    'nextFeed': nextFeed,
    'predation': predation,
    'stock': stock,
    'dead': dead,
    'nextId': nextId,
    'seed': seed,
    'preference': preference.name,
    'levels': {for (final entry in levels.entries) entry.key.name: entry.value},
    'breeders': breeders.toList(),
    'fish': fish.map((item) => item.toJson()).toList(),
  };
}
