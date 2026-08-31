import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import '../models/glossary_term.dart';
import '../models/question.dart';

/// Loads the bundled question bank and glossary once at app start and
/// exposes them in a form the UI can use directly.
class ContentRepository {
  final Map<ExamCategory, List<ExamQuestion>> _byCategory = {
    for (final c in ExamCategory.values) c: [],
  };
  final Map<String, ExamQuestion> _byId = {};
  final List<GlossaryTerm> glossary = [];

  int get totalQuestionCount => _byCategory.values.fold(0, (sum, l) => sum + l.length);

  List<ExamQuestion> questionsFor(ExamCategory category) =>
      List.unmodifiable(_byCategory[category]!);

  ExamQuestion? byId(String id) => _byId[id];

  /// Reconstructs an ordered question list from saved ids (used to resume a
  /// Supabase-backed session). Drops any id that no longer resolves (e.g. the
  /// content was re-parsed and that question's id changed or was dropped).
  List<ExamQuestion> byIds(List<String> ids) => ids.map((id) => _byId[id]).whereType<ExamQuestion>().toList();

  Future<void> load() async {
    final questionsRaw = await rootBundle.loadString('assets/data/questions.json');
    final questionsJson = jsonDecode(questionsRaw) as Map<String, dynamic>;
    for (final entry in questionsJson['questions'] as List) {
      final q = ExamQuestion.tryParse(entry as Map<String, dynamic>);
      if (q != null) {
        _byCategory[q.category]!.add(q);
        _byId[q.id] = q;
      }
    }
    for (final list in _byCategory.values) {
      list.sort((a, b) => a.number.compareTo(b.number));
    }

    final deDefinitionsRaw = await rootBundle.loadString('assets/data/glossary_de.json');
    final deDefinitions = (jsonDecode(deDefinitionsRaw) as Map<String, dynamic>).cast<String, String>();

    final glossaryRaw = await rootBundle.loadString('assets/data/glossary.json');
    final glossaryJson = jsonDecode(glossaryRaw) as List;
    for (final entry in glossaryJson) {
      final map = entry as Map<String, dynamic>;
      final term = GlossaryTerm.tryParse(map, deDefinition: deDefinitions[map['de']]);
      if (term != null) glossary.add(term);
    }
  }

  /// Builds a 60-question mock exam: exactly 10 random questions from each
  /// of the 6 official categories, in randomized category order.
  List<ExamQuestion> buildMockExam({int perCategory = 10, Random? random}) {
    final rng = random ?? Random();
    final result = <ExamQuestion>[];
    for (final category in ExamCategory.values) {
      final pool = List<ExamQuestion>.from(_byCategory[category]!)..shuffle(rng);
      result.addAll(pool.take(perCategory));
    }
    result.shuffle(rng);
    return result;
  }

  List<ExamQuestion> studySetFor(ExamCategory category, {Random? random}) {
    final pool = List<ExamQuestion>.from(_byCategory[category]!);
    pool.shuffle(random ?? Random());
    return pool;
  }
}
