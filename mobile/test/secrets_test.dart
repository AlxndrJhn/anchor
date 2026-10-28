import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/domain/note_filters.dart';
import 'package:anchor/features/notes/domain/secrets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finds ids, keys and tokens in known formats', () {
    for (final secret in [
      'id 3f2504e0-4f89-11d3-9a0c-0305e82c3301',
      'ghp_abcdefghijklmnopqrstuvwxyz0123456789',
      'AKIAIOSFODNN7EXAMPLE',
      'AIzaSyD-abcdefghijklmnopqrstuvwxyz01234',
      'xoxb-1234567890-abcdefghij',
      'sk_live_abcdefghijklmnop1234',
      'sk-ant-api03-abcdefghijklmnopqrstuv',
      'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N',
      '-----BEGIN RSA PRIVATE KEY-----',
      'Authorization: Bearer abcdefghijklmnop1234',
      'sha d41d8cd98f00b204e9800998ecf8427e',
    ]) {
      expect(containsSecret(secret), isTrue, reason: secret);
    }
  });

  test('finds passwords: labelled, or a typical strong one', () {
    expect(containsSecret('wifi password: hunter2'), isTrue);
    expect(containsSecret('PIN=1234'), isTrue);
    expect(containsSecret('Passwort: Sommer2026'), isTrue);
    expect(containsSecret('login with Tr0ub4dor&3 tomorrow'), isTrue);
  });

  test('leaves ordinary notes alone', () {
    for (final text in [
      'Milk, eggs, Bread & Butter',
      'Call Anna at 15:30 about the 2 tickets',
      'https://Example.com/Path?a=1&B=2',
      'Mail John.Doe1@Example.com!',
      'The password is in the drawer',
      'Version 1.2.3-beta',
    ]) {
      expect(containsSecret(text), isFalse, reason: text);
    }
  });

  test('the filter looks at the title, text and pictures\' text', () {
    const plain = Note(id: 'n', title: 'Shopping');
    expect(const NoteFilters(secret: true).matches(plain), isFalse);
    expect(
      const NoteFilters(
        secret: true,
      ).matches(plain.copyWith(pictureText: 'PIN: 4711')),
      isTrue,
    );
    expect(
      const NoteFilters(secret: true).matches(
        plain.copyWith(
          content:
              '{"ops":[{"insert":"token ghp_abcdefghijklmnopqrstuvwxyz0123456789\\n"}]}',
        ),
      ),
      isTrue,
    );
  });
}
