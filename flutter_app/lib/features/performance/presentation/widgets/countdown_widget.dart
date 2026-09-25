import 'dart:async';

import 'package:flutter/material.dart';

class CountdownWidget
    extends StatefulWidget {
  final VoidCallback onFinished;

  const CountdownWidget({
    super.key,
    required this.onFinished,
  });

  @override
  State<CountdownWidget> createState() =>
      _CountdownWidgetState();
}

class _CountdownWidgetState
    extends State<CountdownWidget> {
  int count = 3;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (count == 1) {
          _timer?.cancel();

          widget.onFinished();

          return;
        }

        setState(() {
          count--;
        });
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 80,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}