enum ExamCategory {
  allgemeineFischkunde,
  spezielleFischkunde,
  gewaesserkundeUndFischhege,
  naturUndTierschutz,
  geraetekunde,
  gesetzeskunde;

  static ExamCategory fromSlug(String slug) {
    return ExamCategory.values.firstWhere(
      (c) => c.slug == slug,
      orElse: () => throw ArgumentError('Unknown category slug: $slug'),
    );
  }

  String get slug {
    switch (this) {
      case ExamCategory.allgemeineFischkunde:
        return 'allgemeine_fischkunde';
      case ExamCategory.spezielleFischkunde:
        return 'spezielle_fischkunde';
      case ExamCategory.gewaesserkundeUndFischhege:
        return 'gewaesserkunde_und_fischhege';
      case ExamCategory.naturUndTierschutz:
        return 'natur_und_tierschutz';
      case ExamCategory.geraetekunde:
        return 'geraetekunde';
      case ExamCategory.gesetzeskunde:
        return 'gesetzeskunde';
    }
  }

  String get nameDe {
    switch (this) {
      case ExamCategory.allgemeineFischkunde:
        return 'Allgemeine Fischkunde';
      case ExamCategory.spezielleFischkunde:
        return 'Spezielle Fischkunde';
      case ExamCategory.gewaesserkundeUndFischhege:
        return 'Gewässerkunde und Fischhege';
      case ExamCategory.naturUndTierschutz:
        return 'Natur- und Tierschutz';
      case ExamCategory.geraetekunde:
        return 'Gerätekunde';
      case ExamCategory.gesetzeskunde:
        return 'Gesetzeskunde';
    }
  }

  String get nameTr {
    switch (this) {
      case ExamCategory.allgemeineFischkunde:
        return 'Genel Balık Bilgisi';
      case ExamCategory.spezielleFischkunde:
        return 'Özel Balık Bilgisi';
      case ExamCategory.gewaesserkundeUndFischhege:
        return 'Su Bilgisi ve Balık Bakımı';
      case ExamCategory.naturUndTierschutz:
        return 'Doğa ve Hayvan Koruma';
      case ExamCategory.geraetekunde:
        return 'Ekipman Bilgisi';
      case ExamCategory.gesetzeskunde:
        return 'Hukuk Bilgisi';
    }
  }
}

class QuestionOption {
  final String letter;
  final String text;
  final bool correct;

  const QuestionOption({required this.letter, required this.text, required this.correct});

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      letter: json['letter'] as String,
      text: (json['text'] as String).trim(),
      correct: json['correct'] as bool? ?? false,
    );
  }
}

class QuestionText {
  final String question;
  final List<QuestionOption> options;
  final String? note;

  const QuestionText({required this.question, required this.options, this.note});

  factory QuestionText.fromJson(Map<String, dynamic> json) {
    return QuestionText(
      question: (json['question'] as String).trim(),
      options: (json['options'] as List)
          .map((o) => QuestionOption.fromJson(o as Map<String, dynamic>))
          .toList(),
      note: (json['note'] as String?)?.trim(),
    );
  }

  QuestionOption get correctOption => options.firstWhere((o) => o.correct);
}

class ExamQuestion {
  final ExamCategory category;
  final int number;
  final QuestionText de;
  final QuestionText tr;

  const ExamQuestion({
    required this.category,
    required this.number,
    required this.de,
    required this.tr,
  });

  String get id => '${category.slug}_$number';

  /// Only questions with a clean, single-answer DE+TR pair are considered
  /// safe to show in the app. See content/README.md for the ~8 source
  /// questions this filters out and why.
  static ExamQuestion? tryParse(Map<String, dynamic> json) {
    final deJson = json['de'] as Map<String, dynamic>?;
    final trJson = json['tr'] as Map<String, dynamic>?;
    if (deJson == null || trJson == null) return null;

    final de = QuestionText.fromJson(deJson);
    final tr = QuestionText.fromJson(trJson);

    if (de.options.length != 3 || tr.options.length != 3) return null;
    if (de.options.where((o) => o.correct).length != 1) return null;
    if (tr.options.where((o) => o.correct).length != 1) return null;
    if (de.correctOption.letter != tr.correctOption.letter) return null;

    return ExamQuestion(
      category: ExamCategory.fromSlug(json['category'] as String),
      number: json['number'] as int,
      de: de,
      tr: tr,
    );
  }
}
