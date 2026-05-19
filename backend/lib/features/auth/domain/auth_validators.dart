class AuthValidators {
  
  static const supportedCountries = {
    'CR',
    'PA',
    'MX',
    'CO',
    'CL',
    'AR',
  };

  static const supportedLanguages = {
    'es',
    'en',
  };

  static const blockedDomains = {
    'mailinator.com',
    '10minutemail.com',
    'guerrillamail.com',
  };

  static String? validateEmail(String email) {
    final value = email.trim();
    if (value.isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value)) {
      return 'Invalid email format';
    }

    return null;
  }

  static String? validateUsername(String username) {
    final value = username.trim();
    if (value.isEmpty) {
      return 'Username is required';
    }

    if (value.length < 3) {
      return 'Username must be at least 3 characters';
    }

    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(value)) {
      return 'Username can only contain letters, numbers and underscore';
    }

    return null;
  }

  static String? validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password is required';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must contain at least one uppercase letter';
    }

    if (!RegExp(r'\d').hasMatch(password)) {
      return 'Password must contain at least one digit';
    }

    return null;
  }

  static String? validateCountry(String country) {
    if (!supportedCountries.contains(country)) {
      return 'Country not supported';
    }

    return null;
  }

  static String? validateLanguage(String language) {
    if (!supportedLanguages.contains(language)) {
      return 'Language not supported';
    }

    return null;
  }

  static String? validateDisclosure(bool accepted) {
    if (!accepted) {
      return 'Disclosure must be accepted';
    }

    return null;
  }

  static String? validateEmailDomain(String email) {
    final domain = email.split('@').last.toLowerCase();

    if (blockedDomains.contains(domain)) {
      return 'Email domain is not allowed';
    }

    return null;
  }
}