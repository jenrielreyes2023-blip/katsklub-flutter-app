class DailyRewardDay {
  final int day;
  final String type;
  final String title;
  final String description;
  final int? durationDays;
  final String icon;
  final String badge;
  final List<int>? coinsRange;
  final bool isClaimed;
  final bool isToday;
  final bool isLocked;

  const DailyRewardDay({
    required this.day,
    required this.type,
    required this.title,
    required this.description,
    this.durationDays,
    required this.icon,
    required this.badge,
    this.coinsRange,
    this.isClaimed = false,
    this.isToday = false,
    this.isLocked = false,
  });

  factory DailyRewardDay.fromJson(Map<String, dynamic> json) {
    List<int>? range;
    if (json['coinsRange'] is List) {
      range = (json['coinsRange'] as List).map((e) => (e as num).toInt()).toList();
    }
    return DailyRewardDay(
      day: (json['day'] as num?)?.toInt() ?? 1,
      type: json['type']?.toString() ?? 'coins',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      durationDays: (json['durationDays'] as num?)?.toInt(),
      icon: json['icon']?.toString() ?? 'gift',
      badge: json['badge']?.toString() ?? '',
      coinsRange: range,
      isClaimed: json['isClaimed'] == true,
      isToday: json['isToday'] == true,
      isLocked: json['isLocked'] == true,
    );
  }
}

class ClaimedReward {
  final int day;
  final String type;
  final String title;
  final String description;
  final String? path;
  final String? preview;
  final String? key;
  final String? introUrl;
  final String? loopUrl;
  final int? amount;
  final int? durationDays;
  final String? expiresAt;
  final bool isPermanent;

  const ClaimedReward({
    required this.day,
    required this.type,
    required this.title,
    required this.description,
    this.path,
    this.preview,
    this.key,
    this.introUrl,
    this.loopUrl,
    this.amount,
    this.durationDays,
    this.expiresAt,
    this.isPermanent = false,
  });

  factory ClaimedReward.fromJson(Map<String, dynamic> json) {
    return ClaimedReward(
      day: (json['day'] as num?)?.toInt() ?? 1,
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      path: json['path']?.toString(),
      preview: json['preview']?.toString(),
      key: json['key']?.toString(),
      introUrl: json['introUrl']?.toString(),
      loopUrl: json['loopUrl']?.toString(),
      amount: (json['amount'] as num?)?.toInt(),
      durationDays: (json['durationDays'] as num?)?.toInt(),
      expiresAt: json['expiresAt']?.toString(),
      isPermanent: json['isPermanent'] == true,
    );
  }
}

class DailyRewardsStatus {
  final int currentDay;
  final int streakCount;
  final bool canClaimToday;
  final List<int> claimedDays;
  final int currentCycle;
  final String today;
  final String lastCheckInDate;
  final bool isAdmin;
  final List<DailyRewardDay> rewards;
  final Map<String, dynamic> userInventory;

  const DailyRewardsStatus({
    required this.currentDay,
    required this.streakCount,
    required this.canClaimToday,
    required this.claimedDays,
    required this.currentCycle,
    required this.today,
    required this.lastCheckInDate,
    required this.isAdmin,
    required this.rewards,
    required this.userInventory,
  });

  factory DailyRewardsStatus.fromJson(Map<String, dynamic> json) {
    final rawRewards = json['rewards'] as List? ?? [];
    final rewardsList = rawRewards
        .whereType<Map<String, dynamic>>()
        .map((e) => DailyRewardDay.fromJson(e))
        .toList();

    final rawClaimed = json['claimedDays'] as List? ?? [];
    final claimed = rawClaimed.map((e) => (e as num).toInt()).toList();

    return DailyRewardsStatus(
      currentDay: (json['currentDay'] as num?)?.toInt() ?? 1,
      streakCount: (json['streakCount'] as num?)?.toInt() ?? 0,
      canClaimToday: json['canClaimToday'] == true,
      claimedDays: claimed,
      currentCycle: (json['currentCycle'] as num?)?.toInt() ?? 1,
      today: json['today']?.toString() ?? '',
      lastCheckInDate: json['lastCheckInDate']?.toString() ?? '',
      isAdmin: json['isAdmin'] == true,
      rewards: rewardsList,
      userInventory: json['userInventory'] is Map<String, dynamic>
          ? json['userInventory'] as Map<String, dynamic>
          : {},
    );
  }
}

class DailyRewardClaimResult {
  final bool ok;
  final String message;
  final ClaimedReward? reward;
  final int currentDay;
  final int streakCount;
  final List<int> claimedDays;
  final int currentCycle;
  final double coinsBalance;
  final bool canClaimToday;
  final String? error;

  const DailyRewardClaimResult({
    required this.ok,
    required this.message,
    this.reward,
    required this.currentDay,
    required this.streakCount,
    required this.claimedDays,
    required this.currentCycle,
    required this.coinsBalance,
    required this.canClaimToday,
    this.error,
  });

  factory DailyRewardClaimResult.fromJson(Map<String, dynamic> json) {
    final rawClaimed = json['claimedDays'] as List? ?? [];
    final claimed = rawClaimed.map((e) => (e as num).toInt()).toList();

    return DailyRewardClaimResult(
      ok: json['ok'] == true,
      message: json['message']?.toString() ?? '',
      reward: json['reward'] != null ? ClaimedReward.fromJson(json['reward']) : null,
      currentDay: (json['currentDay'] as num?)?.toInt() ?? 1,
      streakCount: (json['streakCount'] as num?)?.toInt() ?? 0,
      claimedDays: claimed,
      currentCycle: (json['currentCycle'] as num?)?.toInt() ?? 1,
      coinsBalance: (json['coinsBalance'] as num?)?.toDouble() ?? 0.0,
      canClaimToday: json['canClaimToday'] == true,
      error: json['error']?.toString(),
    );
  }
}
