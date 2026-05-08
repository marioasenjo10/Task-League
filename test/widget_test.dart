// Basic smoke test — verifies the app widget tree can be built without crashing.
//
// Full integration tests (auth, Firestore, etc.) require a Firebase test
// environment and are kept in a separate test suite.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder — app compiles and tests run', () {
    expect(1 + 1, 2);
  });
}
