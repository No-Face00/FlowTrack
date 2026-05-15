/// Email validation and disposable-domain blocking for auth flows.
class EmailValidator {
  EmailValidator._();

  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  /// Common disposable / temporary email domains.
  static const _blockedDomains = {
    'mailinator.com',
    'guerrillamail.com',
    'guerrillamail.net',
    'sharklasers.com',
    'grr.la',
    'tempmail.com',
    'temp-mail.org',
    'throwaway.email',
    'yopmail.com',
    'trashmail.com',
    '10minutemail.com',
    'fakeinbox.com',
    'getnada.com',
    'maildrop.cc',
    'dispostable.com',
    'mintemail.com',
    'emailondeck.com',
    'tempail.com',
    'burnermail.io',
    'mailnesia.com',
  };

  static String? validate(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Email is required';
    }
    final email = raw.trim().toLowerCase();
    if (!_emailRegex.hasMatch(email)) {
      return 'Enter a valid email address';
    }
    final domain = email.split('@').last;
    if (_blockedDomains.contains(domain)) {
      return 'Temporary email addresses are not allowed';
    }
    return null;
  }

  static bool isValid(String email) => validate(email) == null;
}
