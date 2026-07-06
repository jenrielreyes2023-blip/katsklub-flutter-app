import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

class WalletBalance {
  const WalletBalance({
    required this.balanceCents,
    required this.currency,
  });

  final int balanceCents;
  final String currency;

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    return WalletBalance(
      balanceCents: (json['balanceCents'] as num?)?.toInt() ?? 0,
      currency: (json['currency'] as String?)?.trim().isNotEmpty == true
          ? json['currency'] as String
          : 'PHP',
    );
  }

  static const WalletBalance zero = WalletBalance(
    balanceCents: 0,
    currency: 'PHP',
  );
}

class WalletCounterparty {
  const WalletCounterparty({
    required this.username,
    required this.fullName,
    required this.avatarUrl,
  });

  final String username;
  final String fullName;
  final String avatarUrl;

  factory WalletCounterparty.fromJson(Map<String, dynamic> json) {
    return WalletCounterparty(
      username: (json['username'] as String?) ?? '',
      fullName: (json['fullName'] as String?) ?? '',
      avatarUrl: (json['avatarUrl'] as String?) ?? '',
    );
  }
}

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.kind,
    required this.amountCents,
    required this.note,
    required this.createdAt,
    required this.counterparty,
  });

  final String id;
  final String kind;
  final int amountCents;
  final String note;
  final DateTime? createdAt;
  final WalletCounterparty? counterparty;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    final counterpartyJson = json['counterparty'];
    return WalletTransaction(
      id: (json['id']?.toString() ?? ''),
      kind: (json['kind'] as String?) ?? '',
      amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
      note: (json['note'] as String?) ?? '',
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? ''),
      counterparty: counterpartyJson is Map<String, dynamic>
          ? WalletCounterparty.fromJson(counterpartyJson)
          : null,
    );
  }
}

class WalletException implements Exception {
  WalletException(this.message);
  final String message;
  @override
  String toString() => message;
}

class WalletService {
  WalletService({
    AuthService? authService,
    http.Client? client,
  })  : _authService = authService ?? AuthService(),
        _client = client ?? http.Client();

  final AuthService _authService;
  final http.Client _client;

  Future<String> _requireToken() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw WalletException('You need to sign in again.');
    }
    return token;
  }

  Map<String, String> _headers(String token, {bool json = false}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    return headers;
  }

  Future<WalletBalance> fetchBalance() async {
    final token = await _requireToken();
    final response = await _client.get(
      ApiConfig.uri('/api/wallet'),
      headers: _headers(token),
    );
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw WalletException(_errorMessage(data) ?? 'Failed to load wallet.');
    }
    return WalletBalance.fromJson(data);
  }

  Future<List<WalletTransaction>> fetchTransactions({int limit = 50}) async {
    final token = await _requireToken();
    final response = await _client.get(
      ApiConfig.uri('/api/wallet/transactions?limit=$limit'),
      headers: _headers(token),
    );
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw WalletException(
          _errorMessage(data) ?? 'Failed to load transactions.');
    }
    final list = data['transactions'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((m) => WalletTransaction.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  Future<WalletBalance> topUp({required int amountCents}) async {
    final token = await _requireToken();
    final response = await _client.post(
      ApiConfig.uri('/api/wallet/topup'),
      headers: _headers(token, json: true),
      body: jsonEncode({'amountCents': amountCents}),
    );
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw WalletException(_errorMessage(data) ?? 'Top-up failed.');
    }
    final wallet = data['wallet'];
    if (wallet is Map<String, dynamic>) {
      return WalletBalance.fromJson(wallet);
    }
    return WalletBalance.zero;
  }

  Future<WalletBalance> send({
    required String recipientUsername,
    required int amountCents,
    String note = '',
  }) async {
    final token = await _requireToken();
    final response = await _client.post(
      ApiConfig.uri('/api/wallet/send'),
      headers: _headers(token, json: true),
      body: jsonEncode({
        'recipientUsername': recipientUsername,
        'amountCents': amountCents,
        'note': note,
      }),
    );
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw WalletException(_errorMessage(data) ?? 'Send failed.');
    }
    final wallet = data['wallet'];
    if (wallet is Map<String, dynamic>) {
      return WalletBalance.fromJson(wallet);
    }
    return WalletBalance.zero;
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return <String, dynamic>{};
  }

  String? _errorMessage(Map<String, dynamic> data) {
    final error = data['error'];
    if (error is String && error.trim().isNotEmpty) return error.trim();
    return null;
  }
}
