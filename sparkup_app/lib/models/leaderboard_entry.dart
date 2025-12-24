class LeaderboardEntry {
  final int rank;
  final String? email;
  final String? username; // added: optional username
  final int score;

  LeaderboardEntry(
      {required this.rank, this.email, this.username, required this.score});

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'],
      email: json['email'],
      username: json['username'], // prefer username if provided by backend
      score: json['score'],
    );
  }
}
