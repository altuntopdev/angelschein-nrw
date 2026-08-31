/// Project keys for the app's Supabase backend (progress sync only — no AI,
/// no other backend calls). The anon key is meant to be public; row-level
/// security on every table is what actually protects user data.
class SupabaseConfig {
  static const url = 'https://jkysvfvgxncksiryatvs.supabase.co';
  static const anonKey = 'sb_publishable_W9Ovj2ZLRbE1q_LKUnSbPA_LE-tPLDr';
}
