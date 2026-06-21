import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'payment_verification_page.dart';

class ToyyibPayWebViewPage extends StatefulWidget {
  final String jobId;
  final String paymentUrl;
  final String returnUrl;

  const ToyyibPayWebViewPage({
    super.key,
    required this.jobId,
    required this.paymentUrl,
    required this.returnUrl,
  });

  @override
  State<ToyyibPayWebViewPage> createState() => _ToyyibPayWebViewPageState();
}

class _ToyyibPayWebViewPageState extends State<ToyyibPayWebViewPage> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _handled = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF121212))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (req) {
            if (_isReturnUrl(req.url)) {
              _goToVerification();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url != null && _isReturnUrl(url)) {
              _goToVerification();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  bool _isReturnUrl(String url) {
    final target = Uri.tryParse(widget.returnUrl);
    final incoming = Uri.tryParse(url);
    if (target == null || incoming == null) return false;
    return incoming.host == target.host && incoming.path == target.path;
  }

  void _goToVerification() {
    if (_handled || !mounted) return;
    _handled = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentVerificationPage(jobId: widget.jobId),
      ),
    );
  }

  Future<bool> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Cancel payment?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Leaving will abandon the ToyyibPay session. Your booking will remain as Pending.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay', style: TextStyle(color: Colors.yellow)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A1A),
          elevation: 0,
          title: const Text('ToyyibPay',
              style: TextStyle(color: Colors.white)),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(color: Colors.yellow),
              ),
          ],
        ),
      ),
    );
  }
}
