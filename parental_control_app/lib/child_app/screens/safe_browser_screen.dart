import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/firebase_services/firestore_service.dart';
import '../../shared/models/rules_model.dart';

/// In-app browser that respects parent's allowed/blocked domain rules.
class SafeBrowserScreen extends StatefulWidget {
  const SafeBrowserScreen({super.key});

  @override
  State<SafeBrowserScreen> createState() => _SafeBrowserScreenState();
}

class _SafeBrowserScreenState extends State<SafeBrowserScreen> {
  late final WebViewController _controller;
  RulesModel? _rules;
  final _urlController = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    _loadRulesAndSetup();
  }

  Future<void> _loadRulesAndSetup() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('child_device_id');
    if (deviceId == null || !mounted) return;
    final firestore = context.read<FirestoreService>();
    final rules = await firestore.getRules(deviceId);
    if (!mounted) return;
    setState(() {
      _rules = rules;
      _loading = false;
    });
    _controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (request) => _onNavigationRequest(request.url),
      ),
    );
  }

  static const _blockedHtml = 'data:text/html;charset=utf-8,'
      '%3Chtml%3E%3Cbody%20style%3D%22font-family%3Asans-serif%3Btext-align%3Acenter%3Bpadding%3A2em%22%3E'
      '%3Ch1%3EBlocked%20by%20parent%3C%2Fh1%3E%3Cp%3EThis%20site%20is%20not%20allowed%20by%20your%20parent.%3C%2Fp%3E%3C%2Fbody%3E%3C%2Fhtml%3E';

  NavigationDecision _onNavigationRequest(String url) {
    if (_rules == null) return NavigationDecision.navigate;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority) return NavigationDecision.navigate;
    final host = uri.host.toLowerCase();
    final allowed = _rules!.allowedDomains;
    final blocked = _rules!.blockedDomains;
    if (allowed.isNotEmpty) {
      final ok = allowed.any((d) => host == d.toLowerCase() || host.endsWith('.$d'));
      if (!ok) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _controller.loadRequest(Uri.parse(_blockedHtml)));
        return NavigationDecision.prevent;
      }
    }
    if (blocked.any((d) => host == d.toLowerCase() || host.endsWith('.$d'))) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _controller.loadRequest(Uri.parse(_blockedHtml)));
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  void _loadUrl(String url) {
    String u = url.trim();
    if (!u.contains('://')) u = 'https://$u';
    _urlController.text = u;
    _controller.loadRequest(Uri.parse(u));
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Browser'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: 'Enter URL',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => _loadUrl(_urlController.text),
                ),
              ),
              onSubmitted: _loadUrl,
            ),
          ),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
