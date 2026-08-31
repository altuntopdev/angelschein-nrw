import 'package:flutter/foundation.dart';

import 'progress_service.dart';

/// Shared, app-wide "which questions am I currently getting wrong" state.
/// [ProgressService] itself has no listeners — this wraps it so any screen
/// (currently just the Kategoriler home) can reactively show an up-to-date
/// count without each quiz-launch site having to know who else needs telling.
class MissedQuestionsController extends ChangeNotifier {
  final ProgressService _progress;
  MissedQuestionsController(this._progress);

  List<String> _missedIds = const [];
  List<String> get missedIds => _missedIds;

  Future<void> refresh() async {
    await _progress.ensureSignedIn();
    _missedIds = await _progress.fetchMissedQuestionIds();
    notifyListeners();
  }
}
