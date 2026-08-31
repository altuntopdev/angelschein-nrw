class GlossaryTerm {
  final String de;
  final String tr;
  final String? latin;

  /// A German-language definition, authored separately for users who chose
  /// "Almanca biliyorum" (fluent) — they don't need the Turkish translation,
  /// they need to know what the German word actually means. Not present for
  /// every term.
  final String? deDefinition;

  const GlossaryTerm({required this.de, required this.tr, this.latin, this.deDefinition});

  static GlossaryTerm? tryParse(Map<String, dynamic> json, {String? deDefinition}) {
    if (json['orphan'] == true) return null;
    final de = json['de'] as String?;
    final tr = json['tr'] as String?;
    if (de == null || de.trim().isEmpty) return null;
    if (tr == null || tr.trim().isEmpty) return null;
    final lat = json['lat'] as String?;
    return GlossaryTerm(
      de: de.trim(),
      tr: tr.trim(),
      latin: (lat != null && lat.trim().isNotEmpty) ? lat.trim() : null,
      deDefinition: deDefinition,
    );
  }
}
