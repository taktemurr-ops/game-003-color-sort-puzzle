import 'package:flutter_test/flutter_test.dart';
import 'package:game_003_color_sort_puzzle/monetization/reward_gate.dart';

void main() {
  test('unverified or incomplete ads never grant rewards', () {
    final gate = RewardGate();
    expect(gate.claim(RewardKind.hint, null), RewardOutcome.rejected);
    expect(gate.claim(RewardKind.hint, const VerifiedRewardProof(
      transactionId: 'a', completed: false, serverVerified: true)), RewardOutcome.rejected);
    expect(gate.claim(RewardKind.hint, const VerifiedRewardProof(
      transactionId: 'a', completed: true, serverVerified: false)), RewardOutcome.rejected);
    expect(gate.balance(RewardKind.hint), 0);
  });
  test('transaction IDs are trimmed and cannot be replayed', () {
    final gate = RewardGate();
    expect(gate.claim(RewardKind.hint, const VerifiedRewardProof(
      transactionId: ' reward-1 ', completed: true, serverVerified: true)), RewardOutcome.granted);
    expect(gate.claim(RewardKind.extraMove, const VerifiedRewardProof(
      transactionId: 'reward-1', completed: true, serverVerified: true)), RewardOutcome.duplicate);
    expect(gate.balance(RewardKind.extraMove), 0);
  });
  test('earned rewards can only be consumed once', () {
    final gate = RewardGate();
    expect(gate.claim(RewardKind.hint, const VerifiedRewardProof(
      transactionId: 'reward-2', completed: true, serverVerified: true)), RewardOutcome.granted);
    expect(gate.consume(RewardKind.hint), true);
    expect(gate.consume(RewardKind.hint), false);
  });
  test('empty proof ID cannot grant rewards', () {
    final gate = RewardGate();
    expect(gate.claim(RewardKind.hint, const VerifiedRewardProof(
      transactionId: '  ', completed: true, serverVerified: true)), RewardOutcome.rejected);
  });
}
