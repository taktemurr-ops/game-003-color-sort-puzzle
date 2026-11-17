import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_003_color_sort_puzzle/monetization/reward_claim_gate.dart';

class _Verifier implements RewardReceiptVerifier {
  _Verifier(this.verifyResult);
  final Future<bool> Function() verifyResult;
  int calls = 0;
  @override
  Future<bool> verify({required String accountId, required String placementId,
      required String receiptId}) {
    calls++;
    return verifyResult();
  }
}

void main() {
  test('no opt-in means no reward and no verifier call', () async {
    final verifier = _Verifier(() async => true);
    final gate = RewardClaimGate(verifier);
    expect(await gate.claim(accountId: 'a', placementId: 'hint',
        receiptId: 'r', userOptedIn: false), isFalse);
    expect(verifier.calls, 0);
  });
  test('only a verified receipt grants once', () async {
    var approved = false;
    final gate = RewardClaimGate(_Verifier(() async => approved));
    Future<bool> claim() => gate.claim(accountId: 'a',
        placementId: 'hint', receiptId: 'r', userOptedIn: true);
    expect(await claim(), isFalse);
    approved = true;
    expect(await claim(), isTrue);
    expect(await claim(), isFalse);
  });
  test('simultaneous claims are idempotent in one session', () async {
    final pending = Completer<bool>();
    final verifier = _Verifier(() => pending.future);
    final gate = RewardClaimGate(verifier);
    Future<bool> claim() => gate.claim(accountId: 'a',
        placementId: 'hint', receiptId: 'r', userOptedIn: true);
    final first = claim();
    expect(await claim(), isFalse);
    pending.complete(true);
    expect(await first, isTrue);
    expect(verifier.calls, 1);
  });
  test('verifier errors fail closed', () async {
    final gate = RewardClaimGate(_Verifier(() async => throw StateError('offline')));
    expect(await gate.claim(accountId: 'a', placementId: 'hint',
        receiptId: 'r', userOptedIn: true), isFalse);
  });
}
