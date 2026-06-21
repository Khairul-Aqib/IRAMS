import 'package:cloud_firestore/cloud_firestore.dart';

/// FPX transaction status codes per Merchant Interface Specification (MIS).
enum FpxTxnStatus {
  successful,  // "00"
  failed,      // "99" or other non-00
  pending,     // Awaiting bank response
}

/// Represents a single FPX payment transaction.
class FpxTransaction {
  final String fpxTxnId;          // Unique ID returned by FPX
  final String sellerOrderNo;     // Our job/order reference
  final String buyerBankId;       // Buyer bank code (e.g. "ABB0233")
  final String buyerName;         // Buyer name from FPX response
  final double amount;            // Transaction amount in MYR
  final String txnCurrency;       // "MYR"
  final FpxTxnStatus status;
  final String debitAuthCode;     // "00" for success
  final DateTime transactionTime;

  FpxTransaction({
    required this.fpxTxnId,
    required this.sellerOrderNo,
    required this.buyerBankId,
    required this.buyerName,
    required this.amount,
    this.txnCurrency = 'MYR',
    required this.status,
    required this.debitAuthCode,
    required this.transactionTime,
  });

  bool get isSuccessful => status == FpxTxnStatus.successful;

  /// Parse from FPX indirect (back-end) callback query parameters.
  factory FpxTransaction.fromFpxCallback(Map<String, String> params) {
    final code = params['fpx_debitAuthCode'] ?? '99';
    return FpxTransaction(
      fpxTxnId: params['fpx_fpxTxnId'] ?? '',
      sellerOrderNo: params['fpx_sellerOrderNo'] ?? '',
      buyerBankId: params['fpx_buyerBankId'] ?? '',
      buyerName: params['fpx_buyerName'] ?? '',
      amount: double.tryParse(params['fpx_txnAmount'] ?? '0') ?? 0,
      txnCurrency: params['fpx_txnCurrency'] ?? 'MYR',
      status: code == '00' ? FpxTxnStatus.successful : FpxTxnStatus.failed,
      debitAuthCode: code,
      transactionTime: DateTime.tryParse(
            params['fpx_fpxTxnTime'] ?? '',
          ) ??
          DateTime.now(),
    );
  }

  /// Convert to Firestore-friendly map for the payment sub-record.
  Map<String, dynamic> toFirestore() => {
        'FpxTxnId': fpxTxnId,
        'SellerOrderNo': sellerOrderNo,
        'BuyerBankId': buyerBankId,
        'BuyerName': buyerName,
        'Amount': amount,
        'TxnCurrency': txnCurrency,
        'Status': debitAuthCode,
        'TransactionTime': Timestamp.fromDate(transactionTime),
      };
}

