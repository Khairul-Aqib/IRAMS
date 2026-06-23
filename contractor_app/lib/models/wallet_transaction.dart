import 'package:cloud_firestore/cloud_firestore.dart';

enum WalletTxType { earning, deduction, withdrawal, topup }

class WalletTransaction {
  final String id;
  final double amount;
  final WalletTxType type;
  final String description;
  final String status;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.description,
    required this.status,
    required this.createdAt,
  });

  factory WalletTransaction.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data()!;
    return WalletTransaction(
      id: doc.id,
      amount: (d['Amount'] as num?)?.toDouble() ?? 0,
      type: _parseType(d['Type'] as String? ?? ''),
      description: (d['Description'] as String?) ?? '',
      status: (d['Status'] as String?) ?? 'completed',
      createdAt:
          (d['CreatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  bool get isPending => status == 'pending';

  static WalletTxType _parseType(String raw) {
    switch (raw) {
      case 'earning':
        return WalletTxType.earning;
      case 'deduction':
        return WalletTxType.deduction;
      case 'withdrawal':
        return WalletTxType.withdrawal;
      case 'topup':
        return WalletTxType.topup;
      default:
        return WalletTxType.earning;
    }
  }

  bool get isCredit =>
      type == WalletTxType.earning || type == WalletTxType.topup;
}
