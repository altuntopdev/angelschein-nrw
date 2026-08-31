import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A saved quiz run — enough to reconstruct the exact question order and
/// where the user left off.
class SavedSession {
  final String id;
  final String mode; // 'category' | 'mock_exam'
  final String? category;
  final List<String> questionIds;
  final List<bool> results;
  final int currentIndex;
  final int? timeLimitSeconds;
  final int? remainingSeconds;

  SavedSession({
    required this.id,
    required this.mode,
    required this.category,
    required this.questionIds,
    required this.results,
    required this.currentIndex,
    required this.timeLimitSeconds,
    required this.remainingSeconds,
  });

  factory SavedSession.fromRow(Map<String, dynamic> row) {
    return SavedSession(
      id: row['id'] as String,
      mode: row['mode'] as String,
      category: row['category'] as String?,
      questionIds: (row['question_ids'] as List).cast<String>(),
      results: (row['results'] as List).cast<bool>(),
      currentIndex: row['current_index'] as int,
      timeLimitSeconds: row['time_limit_seconds'] as int?,
      remainingSeconds: row['remaining_seconds'] as int?,
    );
  }
}

/// Syncs quiz progress to Supabase so a user can resume where they left off,
/// or explicitly start over. Every call is best-effort: if the network is
/// down or the backend isn't reachable, failures are swallowed so the quiz
/// itself — which works entirely offline from bundled content — is never
/// blocked by this.
class ProgressService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> ensureSignedIn() async {
    if (_client.auth.currentUser != null) return;
    try {
      await _client.auth.signInAnonymously(data: {'platform': _platformLabel});
    } catch (e) {
      debugPrint('ProgressService.ensureSignedIn failed (continuing offline): $e');
    }
  }

  /// Only used for a coarse Android/iOS/web usage count in Supabase — not a
  /// tracking SDK, no third party ever sees this, just one label stored on
  /// our own anonymous auth user record.
  String get _platformLabel {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'other';
    }
  }

  String? get userId => _client.auth.currentUser?.id;

  Future<SavedSession?> findResumable({required String mode, String? category}) async {
    final uid = userId;
    if (uid == null) return null;
    try {
      // mode already disambiguates 'mock_exam' (always category == null) from
      // 'category' runs, so the category filter is only needed in the latter
      // case — this also sidesteps needing an IS NULL filter builder.
      var query = _client
          .from('quiz_sessions')
          .select()
          .eq('user_id', uid)
          .eq('mode', mode)
          .eq('status', 'in_progress');
      if (category != null) {
        query = query.eq('category', category);
      }
      final row = await query.order('updated_at', ascending: false).limit(1).maybeSingle();
      if (row == null) return null;
      return SavedSession.fromRow(row);
    } catch (e) {
      debugPrint('ProgressService.findResumable failed: $e');
      return null;
    }
  }

  Future<String?> createSession({
    required String mode,
    String? category,
    required List<String> questionIds,
    int? timeLimitSeconds,
  }) async {
    final uid = userId;
    if (uid == null) return null;
    try {
      final row = await _client
          .from('quiz_sessions')
          .insert({
            'user_id': uid,
            'mode': mode,
            'category': category,
            'question_ids': questionIds,
            'results': <bool>[],
            'current_index': 0,
            'time_limit_seconds': timeLimitSeconds,
            'remaining_seconds': timeLimitSeconds,
          })
          .select('id')
          .single();
      return row['id'] as String;
    } catch (e) {
      debugPrint('ProgressService.createSession failed (continuing without sync): $e');
      return null;
    }
  }

  Future<void> discardSession(String sessionId) async {
    try {
      await _client.from('quiz_sessions').delete().eq('id', sessionId);
    } catch (e) {
      debugPrint('ProgressService.discardSession failed: $e');
    }
  }

  /// Logs one individual answer to history. Fired the moment the user picks
  /// an option — independent of the session checkpoint below, so the
  /// "remembers past questions" history is accurate even if the app closes
  /// before the user taps "İleri".
  Future<void> logAttempt({
    required String? sessionId,
    required String questionId,
    required String category,
    required bool isCorrect,
  }) async {
    final uid = userId;
    if (uid == null) return;
    try {
      await _client.from('question_attempts').insert({
        'user_id': uid,
        'session_id': sessionId,
        'question_id': questionId,
        'category': category,
        'is_correct': isCorrect,
      });
    } catch (e) {
      debugPrint('ProgressService.logAttempt failed: $e');
    }
  }

  /// Saves resume position: only called at clean question boundaries (after
  /// "İleri"), so resuming always lands on a fresh, unanswered question
  /// rather than needing to reconstruct which option was mid-selected.
  Future<void> checkpoint({
    required String sessionId,
    required int currentIndex,
    required List<bool> results,
    int? remainingSeconds,
  }) async {
    try {
      await _client.from('quiz_sessions').update({
        'current_index': currentIndex,
        'results': results,
        if (remainingSeconds != null) 'remaining_seconds': remainingSeconds,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', sessionId);
    } catch (e) {
      debugPrint('ProgressService.checkpoint failed: $e');
    }
  }

  Future<void> completeSession(String? sessionId) async {
    if (sessionId == null) return;
    try {
      await _client.from('quiz_sessions').update({
        'status': 'completed',
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', sessionId);
    } catch (e) {
      debugPrint('ProgressService.completeSession failed: $e');
    }
  }

  /// Question ids whose most recent attempt was wrong — powers the "Yanlış
  /// Yaptıklarım" review list. A question drops off this list as soon as it's
  /// answered correctly again, so it always reflects current gaps, not a
  /// permanent mistake log.
  Future<List<String>> fetchMissedQuestionIds() async {
    final uid = userId;
    if (uid == null) return [];
    try {
      final rows = await _client
          .from('question_attempts')
          .select('question_id, is_correct')
          .eq('user_id', uid)
          .order('answered_at', ascending: false)
          .limit(2000);
      final seen = <String>{};
      final missed = <String>[];
      for (final row in rows) {
        final id = row['question_id'] as String;
        if (!seen.add(id)) continue; // already saw this question's latest attempt
        if (row['is_correct'] == false) missed.add(id);
      }
      return missed;
    } catch (e) {
      debugPrint('ProgressService.fetchMissedQuestionIds failed: $e');
      return [];
    }
  }

  /// Permanently deletes every synced session and answer history for the
  /// current user (privacy-policy "reset my data" control). Returns whether
  /// it actually reached the server — the caller should tell the user
  /// plainly if it didn't, rather than claim success.
  Future<bool> resetAllProgress() async {
    final uid = userId;
    if (uid == null) return false;
    try {
      await _client.from('quiz_sessions').delete().eq('user_id', uid);
      await _client.from('question_attempts').delete().eq('user_id', uid);
      return true;
    } catch (e) {
      debugPrint('ProgressService.resetAllProgress failed: $e');
      return false;
    }
  }
}
