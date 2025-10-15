// lib/ui/widgets/a11y_toast.dart
// 간단 토스트 (충돌 최소화를 위해 Overlay + AnimatedOpacity)

import 'package:flutter/material.dart';

class A11yToast extends StatefulWidget {
  final String message;
  final Duration duration;
  const A11yToast({super.key, required this.message, this.duration = const Duration(seconds: 2)});

  @override
  State<A11yToast> createState() => _A11yToastState();
}

class _A11yToastState extends State<A11yToast> with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    Future.delayed(widget.duration, () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.85), borderRadius: BorderRadius.circular(12)),
          child: Text(widget.message, style: const TextStyle(color: Colors.white, fontSize: 18)),
        ),
      ),
    );
  }
}

Future<void> showA11yToast(BuildContext context, String message) async {
  await Navigator.of(context).push(PageRouteBuilder(
    opaque: false,
    pageBuilder: (_, __, ___) => A11yToast(message: message),
  ));
}

