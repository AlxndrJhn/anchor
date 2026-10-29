enum RegistrationMode {
  enabled,

  /// Anyone can sign up, and an admin approves the account first.
  review,

  disabled;

  static RegistrationMode parse(String? name) => switch (name) {
    'review' => review,
    'disabled' => disabled,
    _ => enabled,
  };
}
