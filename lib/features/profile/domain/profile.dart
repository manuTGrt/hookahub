class Profile {
  Profile({
    required this.id,
    required this.username,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.birthdate,
  });

  final String id;
  final String username;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final DateTime? birthdate;

  String get firstName {
    if ((displayName ?? '').trim().isEmpty) return '';
    final parts = displayName!.trim().split(RegExp(r"\s+"));
    if (parts.isEmpty) return '';
    return parts.first;
  }

  String get lastName {
    if ((displayName ?? '').trim().isEmpty) return '';
    final parts = displayName!.trim().split(RegExp(r"\s+"));
    if (parts.length <= 1) return '';
    return parts.sublist(1).join(' ');
  }
}

class ProfileUpdate {
  ProfileUpdate({
    this.username,
    this.email,
    this.firstName,
    this.lastName,
    this.birthdate,
    this.avatarUrl,
  });

  final String? username;
  final String? email;
  final String? firstName;
  final String? lastName;
  final DateTime? birthdate;
  final String? avatarUrl;
}
