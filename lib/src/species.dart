enum Brood { live, eggs }

/// Per-species tuning. Day values are in-game days ([Pond.daySeconds] each);
/// ranges are `(min, max)` with max exclusive.
enum Species {
  guppy(
    label: 'Bảy màu',
    latin: 'Poecilia reticulata',
    glyph: '⟫((•›',
    brood: Brood.live,
    adultDays: (54, 69),
    lifeDays: (395, 545),
    clutch: (20, 41),
    spawnEvery: (25, 36),
    incubation: 0,
    hatchRate: 1,
    basePrice: 20,
    vividDivisor: 3,
    adultIncome: 3.3,
    youngIncome: .7,
    load: 1,
    predation: 1,
    pairCost: 90,
    habit:
        'Đẻ con trực tiếp 20–40 con mỗi lứa. Cá lớn ăn cả cá mới đẻ, '
        'rêu Java cho cá con chỗ trốn.',
  ),
  neon(
    label: 'Cá neon',
    latin: 'Paracheirodon innesi',
    glyph: '›══•›',
    brood: Brood.eggs,
    adultDays: (70, 85),
    lifeDays: (600, 900),
    clutch: (100, 201),
    spawnEvery: (20, 30),
    incubation: 1,
    hatchRate: .45,
    fryLoss: .12,
    basePrice: 14,
    vividDivisor: 6,
    adultIncome: 1.6,
    youngIncome: .3,
    load: .5,
    predation: .3,
    pairCost: 140,
    habit:
        'Đẻ 100–200 trứng mỗi đợt, chỉ đẻ khi nước từ 70% trở lên. '
        'Trứng nhạy sáng nên tỷ lệ nở thấp. Đủ đàn 6 con thì ít stress '
        'và kiếm xu nhiều hơn.',
  ),
  betta(
    label: 'Betta',
    latin: 'Betta splendens',
    glyph: '≋≋(•›',
    brood: Brood.eggs,
    adultDays: (90, 110),
    lifeDays: (700, 900),
    clutch: (12, 493),
    spawnEvery: (30, 40),
    incubation: 2,
    hatchRate: .75,
    fryLoss: .25,
    basePrice: 60,
    vividDivisor: 2,
    adultIncome: 6,
    youngIncome: .8,
    load: 1.2,
    predation: 1,
    pairCost: 260,
    habit:
        'Trống nhặt trứng vào tổ bọt và canh tổ nên trứng nở tốt. '
        'Betta trống có tính lãnh thổ: hơn một con trống trưởng thành '
        'trong hồ thì chúng đánh nhau, con thừa không kiếm xu và có thể chết.',
  ),
  corydoras(
    label: 'Cá chuột',
    latin: 'Corydoras aeneus',
    glyph: '›▰•⌟',
    brood: Brood.eggs,
    adultDays: (100, 130),
    lifeDays: (1200, 1800),
    clutch: (100, 201),
    spawnEvery: (25, 35),
    incubation: 4,
    hatchRate: .5,
    fryLoss: .15,
    basePrice: 30,
    vividDivisor: 4,
    adultIncome: 2.4,
    youngIncome: .4,
    load: 1,
    predation: 0,
    pairCost: 200,
    habit:
        'Rà đáy, hiền, không ăn cá con. Cá mái dán từng cụm trứng lên cây: '
        'rêu Java càng dày thì trứng nở càng nhiều. Ăn mồi thừa nên rải '
        'dư ít làm bẩn nước hơn.',
  ),
  angelfish(
    label: 'Thần tiên',
    latin: 'Pterophyllum scalare',
    glyph: '›◇•›',
    brood: Brood.eggs,
    adultDays: (150, 180),
    lifeDays: (2500, 3600),
    clutch: (234, 1083),
    spawnEvery: (35, 45),
    incubation: 3,
    hatchRate: .7,
    fryLoss: .25,
    basePrice: 80,
    vividDivisor: 2,
    adultIncome: 10,
    youngIncome: 1.2,
    load: 2.5,
    predation: 2,
    pairCost: 520,
    habit:
        'Cặp bố mẹ dọn lá hoặc đá để đẻ 234–1.082 trứng rồi canh trứng. '
        'Cặp non thường ăn lứa đầu. Cá lớn săn cá con rất mạnh và làm '
        'bẩn nước nhiều.',
  );

  const Species({
    required this.label,
    required this.latin,
    required this.glyph,
    required this.brood,
    required this.adultDays,
    required this.lifeDays,
    required this.clutch,
    required this.spawnEvery,
    required this.incubation,
    required this.hatchRate,
    this.fryLoss = 0,
    required this.basePrice,
    required this.vividDivisor,
    required this.adultIncome,
    required this.youngIncome,
    required this.load,
    required this.predation,
    required this.pairCost,
    required this.habit,
  });

  final String label;
  final String latin;
  final String glyph;
  final Brood brood;
  final (int, int) adultDays;
  final (int, int) lifeDays;
  final (int, int) clutch;
  final (int, int) spawnEvery;

  /// Days from laying to hatching (egg layers only).
  final int incubation;
  final double hatchRate;

  /// Daily chance that a hatched fry dies in good conditions.
  final double fryLoss;
  final int basePrice;
  final int vividDivisor;
  final double adultIncome;
  final double youngIncome;

  /// Feed and waste load relative to a guppy.
  final double load;

  /// How hard an adult hunts fry. Zero means peaceful.
  final double predation;
  final int pairCost;
  final String habit;

  static const neonSchool = 6;
}
