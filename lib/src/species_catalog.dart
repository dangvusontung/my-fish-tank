import 'dart:convert';

import 'species.dart';

class SpeciesCatalog {
  SpeciesCatalog._(this.revision, Map<String, Species> species)
    : byId = Map.unmodifiable(species);

  static final builtIn = SpeciesCatalog._(0, Species.builtInById);

  factory SpeciesCatalog.decode(String source) {
    final Object? json = jsonDecode(source);
    if (json
        case {
          'schemaVersion': 1,
          'revision': final int revision,
          'species': final List<dynamic> entries,
        }
        when revision > 0 && entries.length <= 128) {
      final species = <String, Species>{};
      for (final entry in entries) {
        if (entry is! Map<String, dynamic>) {
          throw const FormatException('Invalid species entry');
        }
        final item = Species.fromJson(entry);
        if (species.containsKey(item.name)) {
          throw FormatException('Duplicate species ID ${item.name}');
        }
        species[item.name] = item;
      }
      return SpeciesCatalog._(revision, species);
    }
    throw const FormatException('Invalid fish catalog');
  }

  final int revision;
  final Map<String, Species> byId;

  Iterable<Species> get listings =>
      byId.values.where((species) => species.available);
}
