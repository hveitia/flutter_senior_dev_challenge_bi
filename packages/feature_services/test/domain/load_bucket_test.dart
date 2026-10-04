import 'package:feature_services/src/domain/load_bucket.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('puts a load time in its range', () {
    const cases = [
      (Duration.zero, LoadBucket.underOneSecond),
      (Duration(milliseconds: 999), LoadBucket.underOneSecond),
      (Duration(seconds: 1), LoadBucket.oneToThreeSeconds),
      (Duration(milliseconds: 2999), LoadBucket.oneToThreeSeconds),
      (Duration(seconds: 3), LoadBucket.threeToEightSeconds),
      (Duration(milliseconds: 7999), LoadBucket.threeToEightSeconds),
      (Duration(seconds: 8), LoadBucket.overEightSeconds),
      (Duration(minutes: 2), LoadBucket.overEightSeconds),
    ];

    for (final (elapsed, bucket) in cases) {
      expect(LoadBucket.of(elapsed), bucket, reason: '$elapsed');
    }
  });

  test('treats a clock that went backwards as the shortest range', () {
    expect(
      LoadBucket.of(const Duration(seconds: -5)),
      LoadBucket.underOneSecond,
    );
  });
}
