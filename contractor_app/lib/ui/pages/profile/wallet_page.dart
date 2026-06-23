import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:intl/intl.dart';

import '../../../models/contractor.dart';
import '../../../models/wallet_transaction.dart';
import '../../../services/firestore_service.dart';
import '../../../core/theme.dart';
import 'payment_webview_page.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> with WidgetsBindingObserver {
  String? _pendingTopUpId;
  Stream<Contractor?> _contractorStream =
      FirestoreService.instance.watchMyContractor();

  Future<void> _refreshWalletData() async {
    setState(() {
      _contractorStream = FirestoreService.instance.watchMyContractor();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pendingTopUpId != null) {
      _verifyTopUp(_pendingTopUpId!);
    }
  }

  Future<void> _verifyTopUp(String pendingId) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable('verifyTopUpPayment');
      final result = await callable.call<Map<String, dynamic>>({
        'pendingTopUpId': pendingId,
      });
      final status = (result.data['status'] ?? '').toString();
      if (status == 'completed') {
        _pendingTopUpId = null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Top-up confirmed! Wallet credited.'),
              backgroundColor: Color(0xFF4CAF50),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else if (status == 'failed') {
        _pendingTopUpId = null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Top-up failed: ${result.data['detail'] ?? 'Payment was not completed.'}',
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      // If still 'pending', keep _pendingTopUpId so next resume retries
    } catch (e) {
      debugPrint('Top-up verification error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kCard,
        elevation: 0,
        title: const Text(
          'My Wallet',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
      ),
      body: StreamBuilder<Contractor?>(
        stream: _contractorStream,
        builder: (context, snap) {
          final contractor = snap.data;
          final balance = contractor?.walletBalance ?? 0.0;

          return RefreshIndicator(
            color: kYellow,
            backgroundColor: kCard,
            onRefresh: _refreshWalletData,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                // ── Balance card ──
                _BalanceCard(balance: balance),
                const SizedBox(height: 16),

                // ── Action buttons row ──
                Row(
                  children: [
                    // Withdraw
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: balance > 0
                              ? () => _handleWithdraw(context, contractor!)
                              : null,
                          icon: const Icon(Icons.send, size: 18),
                          label: const Text(
                            'Withdraw',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kYellow,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: Colors.white12,
                            disabledForegroundColor: Colors.white24,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Top Up
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: () => _showTopUpDialog(context),
                          icon: const Icon(Icons.add_circle, size: 18),
                          label: const Text(
                            'Top Up',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4CAF50),
                            side: const BorderSide(
                                color: Color(0xFF4CAF50), width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (balance <= 0) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Top up your wallet to cover commissions from cash jobs.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],

                const SizedBox(height: 24),

                // ── Bank & Payments Section ──
                if (contractor != null)
                  _BankSection(contractor: contractor),
                const SizedBox(height: 24),

                // ── Transaction history header ──
                const Text(
                  'Transaction History',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Unified ledger ──
                StreamBuilder<List<WalletTransaction>>(
                  stream: FirestoreService.instance.watchMyTransactions(),
                  builder: (context, txSnap) {
                    if (txSnap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 32),
                          child: CircularProgressIndicator(color: kYellow),
                        ),
                      );
                    }

                    final items = txSnap.data ?? [];

                    if (items.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        alignment: Alignment.center,
                        child: const Column(
                          children: [
                            Icon(Icons.receipt_long, size: 48, color: Colors.white24),
                            SizedBox(height: 12),
                            Text(
                              'No transactions yet',
                              style: TextStyle(color: Colors.white38, fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: items.map((tx) => _TransactionTile(tx: tx)).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleWithdraw(BuildContext context, Contractor contractor) {
    if (!contractor.isBankVerified) {
      // Gate: bank details missing — open bank details dialog inline
      showDialog(
        context: context,
        builder: (_) => _BankDetailsDialog(
          initialBank: contractor.bankName,
          initialAccount: contractor.bankAccountNumber,
          initialHolder: contractor.bankAccountHolderName,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WithdrawSheet(
        currentBalance: contractor.walletBalance,
        bankName: contractor.bankName!,
        bankAccountNumber: contractor.bankAccountNumber!,
        bankAccountHolderName: contractor.bankAccountHolderName ?? '',
      ),
    );
  }

  void _showTopUpDialog(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _TopUpSheet(),
    );
    if (result == '__success__') {
      await _refreshWalletData();
    } else if (result != null && result.isNotEmpty) {
      _pendingTopUpId = result;
    }
  }
}

// ---------------------------------------------------------------------------
// Balance card
// ---------------------------------------------------------------------------

class _BalanceCard extends StatelessWidget {
  final double balance;
  const _BalanceCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    final isNegative = balance < 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          const Text(
            'Available Balance',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Text(
            'RM ${balance.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: isNegative ? Colors.redAccent : kYellow,
            ),
          ),
          if (isNegative) ...[
            const SizedBox(height: 6),
            const Text(
              'You owe commission — balance will recover with FPX jobs.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top-Up bottom sheet
// ---------------------------------------------------------------------------

class _TopUpSheet extends StatefulWidget {
  const _TopUpSheet();

  @override
  State<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<_TopUpSheet> {
  final _amountCtrl = TextEditingController();
  int? _selectedChipIndex;
  bool _isProcessing = false;

  static const _quickAmounts = [20.0, 50.0, 100.0];

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  double? get _resolvedAmount {
    if (_selectedChipIndex != null) return _quickAmounts[_selectedChipIndex!];
    final parsed = double.tryParse(_amountCtrl.text.trim());
    if (parsed != null && parsed > 0) return parsed;
    return null;
  }

  Future<void> _proceed() async {
    final amount = _resolvedAmount;
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid amount'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    // Show non-dismissible loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            color: Color(0xFF1A1A1A),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF4CAF50)),
                  SizedBox(height: 18),
                  Text(
                    'Redirecting to secure\npayment gateway...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      // Resolve contractor ID
      final contractorId =
          await FirestoreService.instance.getMyContractorDocId();
      if (contractorId == null) throw Exception('Contractor not found');

      // Call the Cloud Function (asia-southeast1 region)
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable('createToyyibPayBill');

      final result = await callable.call<Map<String, dynamic>>({
        'type': 'topup',
        'contractorId': contractorId,
        'amount': amount,
      });

      final paymentUrl = (result.data['paymentUrl'] ?? '').toString();
      final pendingTopUpId = (result.data['pendingTopUpId'] ?? '').toString();
      if (paymentUrl.isEmpty) {
        throw Exception('No payment URL returned from server.');
      }

      if (mounted) {
        Navigator.pop(context); // dismiss loading overlay
      }

      // Navigate to the WebView payment page
      if (mounted) {
        final bool? success = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentWebViewPage(
              paymentUrl: paymentUrl,
            ),
          ),
        );

        if (mounted) {
          if (success == true) {
            // Return URL intercepted — payment succeeded
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Top Up Successful!'),
                backgroundColor: Color(0xFF4CAF50),
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.pop(context, '__success__'); // dismiss bottom sheet
          } else {
            // User closed manually — fall back to resume-based verification
            Navigator.pop(context, pendingTopUpId); // dismiss bottom sheet
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Complete your payment in the browser. '
                  'Your balance will update when you return.',
                ),
                backgroundColor: Color(0xFF4CAF50),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Cloud Function error: ${e.code} — ${e.message}');
      if (mounted) {
        Navigator.pop(context); // dismiss loading overlay
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${e.message ?? e.code}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint('Top-up error: $e');
      if (mounted) {
        Navigator.pop(context); // dismiss loading overlay
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Top up failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Top Up Wallet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Add funds via FPX to cover cash-job commissions.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Quick-select chips
            const Text(
              'Quick Select',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(_quickAmounts.length, (i) {
                final selected = _selectedChipIndex == i;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: i < _quickAmounts.length - 1 ? 10 : 0),
                    child: ChoiceChip(
                      label: Text(
                        'RM ${_quickAmounts[i].toInt()}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : Colors.white70,
                        ),
                      ),
                      selected: selected,
                      selectedColor: const Color(0xFF4CAF50),
                      backgroundColor: kCard,
                      side: BorderSide(
                        color: selected
                            ? const Color(0xFF4CAF50)
                            : kBorder,
                      ),
                      onSelected: (_) {
                        setState(() {
                          _selectedChipIndex = selected ? null : i;
                          if (!selected) _amountCtrl.clear();
                        });
                      },
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 18),

            // Custom amount
            const Text(
              'Or enter custom amount',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'e.g. 75.00',
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Icon(Icons.attach_money,
                    color: Colors.white38, size: 20),
                filled: true,
                fillColor: kCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
                ),
              ),
              onChanged: (_) {
                if (_selectedChipIndex != null) {
                  setState(() => _selectedChipIndex = null);
                }
              },
            ),
            const SizedBox(height: 24),

            // Proceed button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _proceed,
                icon: const Icon(Icons.lock, size: 18),
                label: const Text(
                  'Proceed to Payment (FPX)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF4CAF50).withAlpha(80),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Withdraw bottom sheet
// ---------------------------------------------------------------------------

class _WithdrawSheet extends StatefulWidget {
  final double currentBalance;
  final String bankName;
  final String bankAccountNumber;
  final String bankAccountHolderName;

  const _WithdrawSheet({
    required this.currentBalance,
    required this.bankName,
    required this.bankAccountNumber,
    required this.bankAccountHolderName,
  });

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  String get _maskedAccount {
    final acc = widget.bankAccountNumber;
    if (acc.length <= 4) return acc;
    return '**** ${acc.substring(acc.length - 4)}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0 || amount > widget.currentBalance) return;

    setState(() => _isSubmitting = true);

    try {
      await FirestoreService.instance.requestWithdrawal(
        amount: amount,
        bankName: widget.bankName,
        accountNumber: widget.bankAccountNumber,
        accountHolderName: widget.bankAccountHolderName,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Withdrawal of RM ${amount.toStringAsFixed(2)} submitted.',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Withdrawal failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Request Withdrawal',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Available: RM ${widget.currentBalance.toStringAsFixed(2)}',
                style: const TextStyle(color: kYellow, fontSize: 14),
              ),
              const SizedBox(height: 20),

              // Read-only bank details confirmation
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.account_balance,
                          color: Colors.green, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Withdrawing to: ${widget.bankName}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Account: $_maskedAccount',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                          ),
                          if (widget.bankAccountHolderName.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.bankAccountHolderName,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Amount
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: _inputDecoration(
                  label: 'Amount (RM)',
                  icon: Icons.attach_money,
                ),
                validator: (v) {
                  final amount = double.tryParse(v?.trim() ?? '');
                  if (amount == null || amount <= 0) {
                    return 'Enter a valid amount';
                  }
                  if (amount > widget.currentBalance) {
                    return 'Exceeds available balance';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kYellow,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: kYellow.withAlpha(100),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Submit Request',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: Colors.white38, size: 20),
      filled: true,
      fillColor: kCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kYellow, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Unified transaction tile (banking look)
// ---------------------------------------------------------------------------

class _TransactionTile extends StatelessWidget {
  final WalletTransaction tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.isCredit;
    final isPendingWithdrawal =
        tx.type == WalletTxType.withdrawal && tx.isPending;
    final color = isPendingWithdrawal
        ? Colors.orange
        : isCredit
            ? Colors.green
            : Colors.redAccent;
    final sign = isCredit ? '+' : '-';
    final date = DateFormat('dd MMM yyyy, hh:mm a').format(tx.createdAt.toLocal());

    final IconData icon;
    switch (tx.type) {
      case WalletTxType.earning:
        icon = Icons.work;
        break;
      case WalletTxType.deduction:
        icon = Icons.receipt_long;
        break;
      case WalletTxType.withdrawal:
        icon = isPendingWithdrawal ? Icons.hourglass_top : Icons.send;
        break;
      case WalletTxType.topup:
        icon = Icons.add_circle;
        break;
    }

    final title = isPendingWithdrawal
        ? '${tx.description} (Pending)'
        : tx.description;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isPendingWithdrawal ? Colors.orange : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  date,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$sign RM ${tx.amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bank & Payments section (moved from compliance page)
// ---------------------------------------------------------------------------

class _BankSection extends StatelessWidget {
  final Contractor contractor;
  const _BankSection({required this.contractor});

  @override
  Widget build(BuildContext context) {
    final hasBankDetails = contractor.isBankVerified;
    final maskedAccount = _maskAccount(contractor.bankAccountNumber ?? '');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasBankDetails ? kBorder : Colors.orange.withAlpha(120),
          width: hasBankDetails ? 1 : 1.5,
        ),
      ),
      child: hasBankDetails
          ? _buildFilledBank(context, maskedAccount)
          : _buildEmptyBank(context),
    );
  }

  Widget _buildFilledBank(BuildContext context, String maskedAccount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle,
                  color: Colors.green, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contractor.bankName ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    maskedAccount,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _showBankDialog(context),
              child: const Text(
                'Edit',
                style: TextStyle(
                    color: kYellow,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ),
          ],
        ),
        if (contractor.bankAccountHolderName != null &&
            contractor.bankAccountHolderName!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Holder: ${contractor.bankAccountHolderName}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyBank(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.warning_amber_rounded,
            color: Colors.orange, size: 32),
        const SizedBox(height: 10),
        const Text(
          'Bank details required for withdrawals',
          style: TextStyle(
              color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        const Text(
          'Add your bank account to enable earnings withdrawal.',
          style: TextStyle(color: Colors.white38, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showBankDialog(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Update Bank Details'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kYellow,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  String _maskAccount(String account) {
    if (account.length <= 4) return account;
    return '**** ${account.substring(account.length - 4)}';
  }

  void _showBankDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _BankDetailsDialog(
        initialBank: contractor.bankName,
        initialAccount: contractor.bankAccountNumber,
        initialHolder: contractor.bankAccountHolderName,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bank Details Dialog
// ---------------------------------------------------------------------------

class _BankDetailsDialog extends StatefulWidget {
  final String? initialBank;
  final String? initialAccount;
  final String? initialHolder;

  const _BankDetailsDialog({
    this.initialBank,
    this.initialAccount,
    this.initialHolder,
  });

  @override
  State<_BankDetailsDialog> createState() => _BankDetailsDialogState();
}

class _BankDetailsDialogState extends State<_BankDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _accountCtrl;
  late final TextEditingController _holderCtrl;
  late final TextEditingController _customBankCtrl;
  String? _selectedBank;
  bool _saving = false;

  static const _banks = [
    'Maybank',
    'CIMB Bank',
    'Public Bank',
    'RHB Bank',
    'Hong Leong Bank',
    'AmBank',
    'Bank Rakyat',
    'Bank Islam',
    'OCBC Bank',
    'HSBC Bank',
    'Standard Chartered',
    'Alliance Bank',
    'Affin Bank',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _accountCtrl = TextEditingController(text: widget.initialAccount ?? '');
    _holderCtrl = TextEditingController(text: widget.initialHolder ?? '');

    final initial = widget.initialBank;
    if (initial != null && initial.isNotEmpty && !_banks.contains(initial)) {
      _selectedBank = 'Other';
      _customBankCtrl = TextEditingController(text: initial);
    } else {
      _selectedBank = initial;
      _customBankCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _accountCtrl.dispose();
    _holderCtrl.dispose();
    _customBankCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBank == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Select a bank'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final bankName = _selectedBank == 'Other'
        ? _customBankCtrl.text.trim()
        : _selectedBank!;

    if (bankName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter your bank name'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await FirestoreService.instance.updateContractorProfile({
        'BankName': bankName,
        'BankAccountNumber': _accountCtrl.text.trim(),
        'BankAccountHolderName': _holderCtrl.text.trim(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bank details saved.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to save: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bank Account Details',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Used for earnings withdrawal via FPX.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 18),

                DropdownButtonFormField<String>(
                  value: _selectedBank,
                  dropdownColor: kCard,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _inputDeco('Bank Name'),
                  items: _banks
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedBank = v),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Select a bank' : null,
                ),

                if (_selectedBank == 'Other') ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _customBankCtrl,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: _inputDeco('Specify Bank Name'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter your bank name'
                        : null,
                  ),
                ],
                const SizedBox(height: 14),

                TextFormField(
                  controller: _accountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _inputDeco('Account Number'),
                  validator: (v) => (v == null || v.trim().length < 5)
                      ? 'Enter a valid account number'
                      : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _holderCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _inputDeco('Account Holder Name'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter holder name'
                      : null,
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kYellow,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: kYellow.withAlpha(80),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.black),
                          )
                        : const Text('Save Bank Details',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        filled: true,
        fillColor: kBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kYellow, width: 1.5),
        ),
      );
}
