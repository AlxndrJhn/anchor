/// Finds text that looks like a secret: an id, a key or token in a known
/// format, or a password. A rough net for "which notes hold secrets?", not
/// a guarantee either way.
bool containsSecret(String text) =>
    text.isNotEmpty && _patterns.any((pattern) => pattern.hasMatch(text));

final _patterns = <RegExp>[
  // UUIDs, often ids or keys.
  RegExp(
    r'\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b',
    caseSensitive: false,
  ),
  // Keys and tokens with a known prefix: GitHub, GitLab, AWS, Google,
  // Slack, Stripe, OpenAI, Anthropic, npm, PyPI, Hugging Face.
  RegExp(r'\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{30,}'),
  RegExp(r'\bgithub_pat_[A-Za-z0-9_]{40,}'),
  RegExp(r'\bglpat-[A-Za-z0-9_-]{20,}'),
  RegExp(r'\b(?:AKIA|ASIA)[0-9A-Z]{16}\b'),
  RegExp(r'\bAIza[0-9A-Za-z_-]{35}'),
  RegExp(r'\bxox[abprs]-[A-Za-z0-9-]{10,}'),
  RegExp(r'\b(?:sk|pk|rk)_(?:live|test)_[A-Za-z0-9]{16,}'),
  RegExp(r'\bsk-(?:ant-|proj-)?[A-Za-z0-9_-]{20,}'),
  RegExp(r'\bnpm_[A-Za-z0-9]{36}\b'),
  RegExp(r'\bpypi-[A-Za-z0-9_-]{50,}'),
  RegExp(r'\bhf_[A-Za-z0-9]{30,}'),
  // JSON web tokens.
  RegExp(r'\beyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}'),
  // Private keys.
  RegExp(r'-----BEGIN (?:[A-Z]+ )?PRIVATE KEY-----'),
  // A token after "Bearer" or "token:", "api key =" and the like.
  RegExp(
    r'\b(?:bearer|token|api[ _-]?key|secret|client[ _-]?secret)\b\s*[:=]?\s*'
    r'[A-Za-z0-9_\-./+=]{16,}',
    caseSensitive: false,
  ),
  // Long hex strings: hashes, keys.
  RegExp(r'\b[0-9a-f]{32,}\b', caseSensitive: false),
  // A labelled password or PIN, in English or German.
  RegExp(
    r'\b(?:password|passwort|kennwort|passphrase|passcode|pass|pwd|pw|pin)'
    r'\s*[:=]\s*\S+',
    caseSensitive: false,
  ),
  // A password-like word: 8 to 64 characters with lower and upper case
  // letters, a digit and a symbol, and not a link or an email address.
  RegExp(
    r'(?<!\S)(?![^\s]*(?:://|@[A-Za-z0-9-]+\.))'
    r'(?=[^\s]*[a-z])(?=[^\s]*[A-Z])(?=[^\s]*\d)(?=[^\s]*[^\sA-Za-z0-9])'
    r'[^\s]{8,64}(?!\S)',
  ),
];
