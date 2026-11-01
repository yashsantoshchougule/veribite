/// Contract ensuring SQLite FTS5 with trigram tokenization is validated
/// on-device before querying, falling back to bundled sqlite3_flutter_libs C binary.
abstract class FTS5ResilienceContract {
  Future<bool> verifyFTS5Available();
  Future<void> initializeWithFallback();
}
