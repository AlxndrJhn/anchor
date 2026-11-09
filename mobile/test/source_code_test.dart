import 'package:anchor/core/links/source_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const repository = 'https://github.com/AlxndrJhn/anchor-plus';

  test('a release points at its commit', () {
    expect(sourceCodeUrl('0.18.0-fork.09c6c01'), '$repository/tree/09c6c01');
    expect(
      licenseUrl('0.18.0-fork.09c6c01'),
      '$repository/blob/09c6c01/LICENSE',
    );
  });

  test('any other build points at main', () {
    expect(sourceCodeUrl('0.18.0'), '$repository/tree/main');
    expect(sourceCodeUrl(''), '$repository/tree/main');
  });
}
