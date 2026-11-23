/// What a decoration does for the fish that like it.
enum DecorEffect {
  /// Liked adults nearby earn more, up to [Pond.comfortPerDecor] per piece.
  comfort,

  /// Each piece lets one more betta male hold a territory in the main tank.
  territory,

  /// Liked species hatch more of their eggs.
  spawning,

  /// Shelter only.
  none,
}

enum DecorKind {
  rockCave(
    'Hang đá',
    shelter: 5,
    price: 140,
    effect: DecorEffect.comfort,
    likedBy: {'corydoras', 'ram'},
    detail: 'Cá chuột và phượng hoàng ở gần ít stress, kiếm thêm 15% xu.',
  ),
  driftwood(
    'Lũa gỗ',
    shelter: 6,
    price: 180,
    effect: DecorEffect.territory,
    likedBy: {'betta'},
    detail: 'Thêm một lãnh thổ cho betta trống, bớt đánh nhau.',
  ),
  flatStone(
    'Đá phẳng',
    shelter: 2,
    price: 90,
    effect: DecorEffect.spawning,
    likedBy: {'angelfish', 'ram'},
    detail: 'Thần tiên và phượng hoàng đẻ lên đá, trứng nở thêm 10%.',
  ),
  weedClump(
    'Bụi rong',
    shelter: 8,
    price: 120,
    effect: DecorEffect.comfort,
    likedBy: {'neon', 'zebrafish'},
    detail: 'Neon và sọc ngựa bơi đàn yên hơn, kiếm thêm 15% xu.',
  ),
  almondLeaf(
    'Lá bàng khô',
    shelter: 3,
    price: 60,
    effect: DecorEffect.spawning,
    likedBy: {'betta', 'honeyGourami'},
    detail: 'Betta và sặc mật ong làm tổ bọt tốt hơn, trứng nở thêm 10%.',
  ),
  potCave(
    'Hang gốm',
    shelter: 4,
    price: 100,
    effect: DecorEffect.none,
    likedBy: {},
    detail: 'Chỗ trốn chung cho cá con mọi loài.',
  ),
  bigShell(
    'Vỏ ốc lớn',
    shelter: 2,
    price: 40,
    effect: DecorEffect.none,
    likedBy: {},
    detail: 'Thuần trang trí, cá con trốn được vài con.',
  );

  const DecorKind(
    this.label, {
    required this.shelter,
    required this.price,
    required this.effect,
    required this.likedBy,
    required this.detail,
  });

  final String label;

  /// Fry this piece hides from adults.
  final int shelter;
  final int price;
  final DecorEffect effect;

  /// Species IDs that benefit from this piece.
  final Set<String> likedBy;
  final String detail;

  int get resale => price ~/ 2;
}

/// A decoration the player owns. Placed pieces sit on the main tank's
/// floor at [x], [y] (fractions of the tank, before fitting to the
/// screen's controls); stored pieces do nothing.
class Decor {
  Decor({
    required this.id,
    required this.kind,
    this.x = .5,
    this.y = .86,
    this.placed = true,
  });

  factory Decor.fromJson(Map<String, dynamic> json) => Decor(
    id: json['id'] as int,
    kind: DecorKind.values.byName(json['kind'] as String),
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    placed: json['placed'] as bool,
  );

  /// How far up and down the sand a piece may sit.
  static const top = .8;
  static const bottom = .9;

  final int id;
  final DecorKind kind;
  double x;
  double y;
  bool placed;

  void moveTo(double newX, double newY) {
    x = newX.clamp(.06, .94).toDouble();
    y = newY.clamp(top, bottom).toDouble();
  }

  Map<String, Object> toJson() => {
    'id': id,
    'kind': kind.name,
    'x': x,
    'y': y,
    'placed': placed,
  };
}
