import 'package:supabase_flutter/supabase_flutter.dart';

/// Extracts a user-facing explanation from [error], falling back to
/// [fallback] when the error carries no actionable message (e.g. a
/// network failure) or no *curated* one (e.g. a raw constraint violation
/// Postgres generated on its own, such as a unique-key clash on a bare
/// insert). Supabase surfaces our SQL `raise exception` texts through
/// [PostgrestException.message], so this is what lets the specific
/// reason a mutation was refused reach the UI — without ever leaking a
/// table or constraint name.
///
/// Every `raise exception` we write for end users starts with a capital
/// letter (project convention, enforced by the SQL test suite's message
/// review). Postgres' own generated messages (`duplicate key value
/// violates unique constraint "..."`, `null value in column "..."`, ...)
/// always start lowercase. That single, cheap check reliably tells a
/// message we authored apart from one Postgres produced on its own,
/// without hardcoding a list of table/constraint names to hide.
String describeError(Object error, String fallback) {
  if (error is PostgrestException) {
    final message = error.message.trim();
    if (message.isNotEmpty && _isCuratedMessage(message)) return message;
  }
  return fallback;
}

bool _isCuratedMessage(String message) {
  final firstLetter = message[0];
  return firstLetter == firstLetter.toUpperCase() &&
      firstLetter != firstLetter.toLowerCase();
}
