import 'package:cloud_functions/cloud_functions.dart';

class ToyyibPayBill {
  final String billCode;
  final String paymentUrl;
  final String returnUrl;

  const ToyyibPayBill({
    required this.billCode,
    required this.paymentUrl,
    required this.returnUrl,
  });
}

class ToyyibPayService {
  ToyyibPayService._();
  static final instance = ToyyibPayService._();

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  Future<ToyyibPayBill> createBill({
    required String jobId,
    required double amount,
    required String name,
    required String email,
    required String phone,
  }) async {
    final callable = _functions.httpsCallable('createToyyibPayBill');
    final result = await callable.call<Map<Object?, Object?>>({
      'jobId': jobId,
      'amount': amount,
      'userDetails': {
        'name': name,
        'email': email,
        'phone': phone,
      },
    });

    final data = Map<String, dynamic>.from(result.data);
    return ToyyibPayBill(
      billCode: data['billCode'] as String,
      paymentUrl: data['paymentUrl'] as String,
      returnUrl: data['returnUrl'] as String,
    );
  }

  /// Queries ToyyibPay directly for transaction status and forces the
  /// Jobs/{jobId} doc to the authoritative value. Used when the webhook
  /// is delayed or never arrives.
  Future<ToyyibPayStatus> checkStatus({
    required String jobId,
    String? billCode,
  }) async {
    final callable = _functions.httpsCallable('verifyToyyibPayPayment');
    final payload = <String, dynamic>{'jobId': jobId};
    if (billCode != null && billCode.isNotEmpty) {
      payload['billCode'] = billCode;
    }
    final result = await callable.call<Map<Object?, Object?>>(payload);
    final data = Map<String, dynamic>.from(result.data);
    return ToyyibPayStatus(
      paymentStatus: data['paymentStatus'] as String,
      detail: (data['detail'] as String?) ?? '',
    );
  }
}

class ToyyibPayStatus {
  final String paymentStatus; // 'Paid' | 'Failed' | 'Pending' | 'NotFound' | 'Error'
  final String detail;
  const ToyyibPayStatus({required this.paymentStatus, required this.detail});
}
