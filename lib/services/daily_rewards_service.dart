import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/daily_reward_item.dart';
import 'auth_service.dart';

class DailyRewardsService {
  static final DailyRewardsService _instance = DailyRewardsService._internal();
  factory DailyRewardsService() => _instance;
  DailyRewardsService._internal();

  final AuthService _authService = AuthService();

  static final ValueNotifier<DailyRewardsStatus?> statusNotifier =
      ValueNotifier<DailyRewardsStatus?>(null);

  Future<DailyRewardsStatus?> getDailyRewardsStatus() async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) return null;

      final uri = ApiConfig.uri('/api/daily-rewards/status');
      final res = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == true) {
          final status = DailyRewardsStatus.fromJson(data);
          statusNotifier.value = status;
          return status;
        }
      }
    } catch (e) {
      debugPrint('Error getting daily rewards status: $e');
    }
    return null;
  }

  Future<DailyRewardClaimResult?> claimDailyReward() async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        return const DailyRewardClaimResult(
          ok: false,
          message: 'User not authenticated',
          currentDay: 1,
          streakCount: 0,
          claimedDays: [],
          currentCycle: 1,
          coinsBalance: 0,
          canClaimToday: false,
          error: 'User not authenticated',
        );
      }

      final uri = ApiConfig.uri('/api/daily-rewards/claim');
      final res = await http.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['ok'] == true) {
        final result = DailyRewardClaimResult.fromJson(data);
        // Refresh status in background
        getDailyRewardsStatus();
        return result;
      } else {
        return DailyRewardClaimResult(
          ok: false,
          message: data['error'] ?? data['message'] ?? 'Failed to claim reward',
          currentDay: 1,
          streakCount: 0,
          claimedDays: [],
          currentCycle: 1,
          coinsBalance: 0,
          canClaimToday: false,
          error: data['error'] ?? data['message'] ?? 'Failed to claim reward',
        );
      }
    } catch (e) {
      debugPrint('Error claiming daily reward: $e');
      return DailyRewardClaimResult(
        ok: false,
        message: 'Network error claiming daily reward',
        currentDay: 1,
        streakCount: 0,
        claimedDays: [],
        currentCycle: 1,
        coinsBalance: 0,
        canClaimToday: false,
        error: e.toString(),
      );
    }
  }

  /// Check if user has already been shown the daily overlay in this local app calendar day
  Future<bool> hasBeenShownToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastShown = prefs.getString('daily_rewards_last_shown_date');
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      return lastShown == todayStr;
    } catch (_) {
      return false;
    }
  }

  /// Mark that the overlay was shown today so it doesn't repeatedly auto-pop if user closes it
  Future<void> markShownToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      await prefs.setString('daily_rewards_last_shown_date', todayStr);
    } catch (_) {}
  }
}
