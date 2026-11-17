/// No SDK implementation is provided here. A trusted backend must verify receipts.
abstract class RewardReceiptVerifier {
  Future<bool> verify({
    required String accountId,
    required String placementId,
    required String receiptId,
  });
}

/// Session-only replay and concurrent-claim guard; production also needs
/// durable, atomic backend idempotency keyed by account and ad transaction.
class RewardClaimGate {
  RewardClaimGate(this.verifier);
  final RewardReceiptVerifier verifier;
  final Set<String> _claimed = <String>{};
  final Set<String> _pending = <String>{};

  /// Grant a reward only when this returns true. Never require ads to play.
  Future<bool> claim({
    required String accountId,
    required String placementId,
    required String receiptId,
    required bool userOptedIn,
  }) async {
    if (!userOptedIn ||
        accountId.trim().isEmpty ||
        placementId.trim().isEmpty ||
        receiptId.trim().isEmpty) return false;
    final key = '${accountId.length}:$accountId|${placementId.length}:$placementId|$receiptId';
    if (_claimed.contains(key) || !_pending.add(key)) return false;
    try {
      final verified = await verifier.verify(
        accountId: accountId,
        placementId: placementId,
        receiptId: receiptId,
      );
      if (!verified) return false;
      _claimed.add(key);
      return true;
    } catch (_) {
      return false;
    } finally {
      _pending.remove(key);
    }
  }
}
