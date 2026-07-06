import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/wallet_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({required this.user, super.key});

  final User user;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final WalletService _walletService = WalletService();

  WalletBalance _balance = WalletBalance.zero;
  List<WalletTransaction> _transactions = const [];
  bool _isLoading = true;
  String? _error;

  static const List<int> _topUpOptions = [5000, 10000, 50000, 100000];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _walletService.fetchBalance(),
        _walletService.fetchTransactions(),
      ]);
      if (!mounted) return;
      setState(() {
        _balance = results[0] as WalletBalance;
        _transactions = results[1] as List<WalletTransaction>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openTopUpSheet() async {
    if (!widget.user.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Top-up is restricted to admins.')),
      );
      return;
    }
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TopUpSheet(options: _topUpOptions),
    );
    if (selected == null) return;

    try {
      final updated = await _walletService.topUp(amountCents: selected);
      if (!mounted) return;
      setState(() {
        _balance = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Topped up ${_formatPhp(selected)}.')),
      );
      await _refreshTransactions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _openSendSheet() async {
    final result = await showModalBottomSheet<_SendResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SendSheet(balanceCents: _balance.balanceCents),
    );
    if (result == null) return;

    try {
      final updated = await _walletService.send(
        recipientUsername: result.username,
        amountCents: result.amountCents,
        note: result.note,
      );
      if (!mounted) return;
      setState(() {
        _balance = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Sent ${_formatPhp(result.amountCents)} to @${result.username}.'),
        ),
      );
      await _refreshTransactions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _refreshTransactions() async {
    try {
      final txs = await _walletService.fetchTransactions();
      if (!mounted) return;
      setState(() {
        _transactions = txs;
      });
    } catch (_) {}
  }

  static String _formatPhp(int amountCents) {
    final pesos = amountCents / 100;
    return '₱${pesos.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF18191A) : const Color(0xFFF7F7F7);
    final appBarColor = isDark ? const Color(0xFF18191A) : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        surfaceTintColor: appBarColor,
        elevation: 0,
        foregroundColor: titleColor,
        title: Text(
          'Wallet',
          style: TextStyle(fontWeight: FontWeight.w700, color: titleColor),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFFFF7A45),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF7A45)))
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : Colors.black;
    final cardBgColor = isDark ? const Color(0xFF242526) : Colors.white;
    final dividerColor = isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB);
    final emptyTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF5A1E1C) : const Color(0xFFFDECEA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _error!,
              style: TextStyle(color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB71C1C)),
            ),
          ),
          const SizedBox(height: 16),
        ],
        _BalanceCard(balance: _balance),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'Top up',
                icon: Icons.add_circle_outline,
                onTap: widget.user.isAdmin ? _openTopUpSheet : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                label: 'Send',
                icon: Icons.send_rounded,
                onTap: _balance.balanceCents > 0 ? _openSendSheet : null,
              ),
            ),
          ],
        ),
        if (!widget.user.isAdmin) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Icon(Icons.lock_outline,
                    size: 14, color: isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Top-up is admin-only. Receive funds via Send instead.',
                    style: TextStyle(
                      color: isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Transactions',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: titleColor),
        ),
        const SizedBox(height: 8),
        if (_transactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              'No transactions yet.',
              style: TextStyle(color: emptyTextColor),
            ),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ColoredBox(
              color: cardBgColor,
              child: Column(
                children: [
                  for (var i = 0; i < _transactions.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, color: dividerColor),
                    _TransactionTile(transaction: _transactions[i]),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});
  final WalletBalance balance;

  @override
  Widget build(BuildContext context) {
    final pesos = balance.balanceCents / 100;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFB923C), Color(0xFFEA580C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available balance',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            '₱${pesos.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            balance.currency,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onTap != null;
    
    final activeBg = isDark ? const Color(0xFF242526) : Colors.white;
    final disabledBg = isDark ? const Color(0xFF18191A) : const Color(0xFFF3F4F6);
    final activeText = isDark ? Colors.white : Colors.black;
    final disabledText = isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);

    return Material(
      color: enabled ? activeBg : disabledBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon,
                  color: enabled
                      ? const Color(0xFFFF7A45)
                      : const Color(0xFF9CA3AF)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: enabled ? activeText : disabledText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});
  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? const Color(0xFF9CA3AF) : Colors.grey[600];

    final isCredit = transaction.amountCents > 0;
    final amount = transaction.amountCents.abs() / 100;
    final amountText =
        '${isCredit ? '+' : '-'}₱${amount.toStringAsFixed(2)}';
    final counterparty = transaction.counterparty;

    String title;
    IconData icon;
    Color iconColor;
    switch (transaction.kind) {
      case 'topup':
        title = 'Top up';
        icon = Icons.add_circle_outline;
        iconColor = const Color(0xFF10B981);
        break;
      case 'send':
        title = counterparty != null && counterparty.username.isNotEmpty
            ? 'Sent to @${counterparty.username}'
            : 'Sent';
        icon = Icons.arrow_upward_rounded;
        iconColor = const Color(0xFFEF4444);
        break;
      case 'receive':
        title = counterparty != null && counterparty.username.isNotEmpty
            ? 'Received from @${counterparty.username}'
            : 'Received';
        icon = Icons.arrow_downward_rounded;
        iconColor = const Color(0xFF10B981);
        break;
      default:
        title = transaction.kind;
        icon = Icons.swap_horiz;
        iconColor = const Color(0xFF6B7280);
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withValues(alpha: 0.12),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: titleColor)),
      subtitle: transaction.note.isNotEmpty
          ? Text(transaction.note, style: TextStyle(color: subtitleColor))
          : (transaction.createdAt != null
              ? Text(_formatDate(transaction.createdAt!), style: TextStyle(color: subtitleColor))
              : null),
      trailing: Text(
        amountText,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

class _TopUpSheet extends StatefulWidget {
  const _TopUpSheet({required this.options});
  final List<int> options;

  @override
  State<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<_TopUpSheet> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBgColor = isDark ? const Color(0xFF1C1E21) : Colors.white;
    final dragHandleColor = isDark ? const Color(0xFF4E4F51) : const Color(0xFFD1D5DB);
    final titleColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: sheetBgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: dragHandleColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Top up amount',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: titleColor),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final cents in widget.options)
                  ChoiceChip(
                    label: Text(
                      '₱${(cents / 100).toStringAsFixed(0)}',
                      style: TextStyle(
                        color: _selected == cents
                            ? Colors.white
                            : (isDark ? Colors.white : Colors.black),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    selected: _selected == cents,
                    selectedColor: const Color(0xFFFF7A45),
                    backgroundColor: isDark ? const Color(0xFF242526) : Colors.grey[200],
                    onSelected: (_) => setState(() => _selected = cents),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selected == null
                    ? null
                    : () => Navigator.of(context).pop(_selected),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A45),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDark ? const Color(0xFF2D2E30) : Colors.grey[300],
                  disabledForegroundColor: isDark ? const Color(0xFF6B7280) : Colors.grey[500],
                ),
                child: Text(_selected == null
                    ? 'Choose an amount'
                    : 'Confirm ₱${(_selected! / 100).toStringAsFixed(0)} top-up'),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Mock payment for testing.',
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendResult {
  const _SendResult({
    required this.username,
    required this.amountCents,
    required this.note,
  });
  final String username;
  final int amountCents;
  final String note;
}

class _SendSheet extends StatefulWidget {
  const _SendSheet({required this.balanceCents});
  final int balanceCents;

  @override
  State<_SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends State<_SendSheet> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final username = _usernameController.text.trim().replaceFirst('@', '');
    final amountText = _amountController.text.trim();
    final note = _noteController.text.trim();

    if (username.isEmpty) {
      setState(() => _error = 'Enter a recipient username.');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }

    final amountCents = (amount * 100).round();
    if (amountCents > widget.balanceCents) {
      setState(() => _error = 'Insufficient balance.');
      return;
    }

    Navigator.of(context).pop(_SendResult(
      username: username,
      amountCents: amountCents,
      note: note,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBgColor = isDark ? const Color(0xFF1C1E21) : Colors.white;
    final dragHandleColor = isDark ? const Color(0xFF4E4F51) : const Color(0xFFD1D5DB);
    final titleColor = isDark ? Colors.white : Colors.black;

    final insets = MediaQuery.of(context).viewInsets;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: insets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: sheetBgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: dragHandleColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Send money',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: titleColor),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _usernameController,
                style: TextStyle(color: titleColor),
                decoration: InputDecoration(
                  labelText: 'Recipient username',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF9CA3AF) : Colors.grey[600]),
                  prefixText: '@',
                  prefixStyle: TextStyle(color: titleColor),
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: titleColor),
                decoration: InputDecoration(
                  labelText: 'Amount (PHP)',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF9CA3AF) : Colors.grey[600]),
                  prefixText: '₱ ',
                  prefixStyle: TextStyle(color: titleColor),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLength: 200,
                style: TextStyle(color: titleColor),
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF9CA3AF) : Colors.grey[600]),
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _error!,
                    style: TextStyle(color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB71C1C)),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A45),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Send'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
