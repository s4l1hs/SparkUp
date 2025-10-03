class LeaderboardEntry {
  final int rank;
  final String? email;
  final int score;

  LeaderboardEntry({required this.rank, this.email, required this.score});

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'],
      email: json['email'],
      score: json['score'],
    );
  }
}