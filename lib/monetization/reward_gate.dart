/// Policy-only reward gate. No ad SDK or server verification is implemented here.
/// A production adapter must verify completion server-side before passing proof.
enum RewardKind { hint, extraMove, cosmeticToken }
enum RewardOutcome { granted, rejected, duplicate }

class VerifiedRewardProof {
  final String transactionId;
  final bool completed;
  final bool serverVerified;
  const VerifiedRewardProof({
    required this.transactionId,
    required this.completed,
    required this.serverVerified,
  });
}

class RewardGate {
  final Set<String> _usedTransactions = <String>{};
  final Map<RewardKind, int> _balances = {};
  int balance(RewardKind kind) => _balances[kind] ?? 0;

  RewardOutcome claim(RewardKind kind, VerifiedRewardProof? proof) {
    if (proof == null || !proof.completed || !proof.serverVerified) {
      return RewardOutcome.rejected;
    }
    final id = proof.transactionId.trim();
    if (id.isEmpty) return RewardOutcome.rejected;
    if (!_usedTransactions.add(id)) return RewardOutcome.duplicate;
    _balances[kind] = balance(kind) + 1;
    return RewardOutcome.granted;
  }

  bool consume(RewardKind kind) {
    final current = balance(kind);
    if (current <= 0) return false;
    _balances[kind] = current - 1;
    return true;
  }
}
