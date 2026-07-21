import 'package:flutter/material.dart';
import '../widgets/disclaimer_banner.dart';

/// Shared screen scaffold: AppBar + optional persistent disclaimer banner + body.
Widget screenScaffold(
  BuildContext context, {
  required String title,
  required Widget body,
  bool disclaimer = false,
  String disclaimerText = '',
  bool dangerDisclaimer = false,
  List<Widget>? actions,
}) {
  return Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    body: SafeArea(
      child: Column(
        children: [
          if (disclaimer)
            disclaimerText.isNotEmpty
                ? DisclaimerBanner(message: disclaimerText, danger: dangerDisclaimer)
                : const DisclaimerBanner(),
          Expanded(child: body),
        ],
      ),
    ),
  );
}
