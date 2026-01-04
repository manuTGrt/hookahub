class HomeStats {
  const HomeStats({
    required this.tobaccos,
    required this.mixes,
    required this.users,
  });

  final int tobaccos;
  final int mixes;
  final int users;

  static const empty = HomeStats(tobaccos: 0, mixes: 0, users: 0);

  HomeStats copyWith({
    int? tobaccos,
    int? mixes,
    int? users,
  }) {
    return HomeStats(
      tobaccos: tobaccos ?? this.tobaccos,
      mixes: mixes ?? this.mixes,
      users: users ?? this.users,
    );
  }
}
