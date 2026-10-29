/// Must match what the server accepts for an account.
library;

const int minPasswordLength = 8;
const int maxNameLength = 100;

bool isNameValid(String name) => name.trim().isNotEmpty;

bool isEmailValid(String email) => _emailPattern.hasMatch(email.trim());

bool isNewPasswordValid(String password) =>
    password.length >= minPasswordLength;

final _emailPattern = RegExp(r'.+@.+\..+');
