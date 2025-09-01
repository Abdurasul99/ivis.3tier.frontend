import 'package:flutter/material.dart';

class TabAnalyze extends StatefulWidget {
  const TabAnalyze({super.key});

  @override
  State<TabAnalyze> createState() => _TabAnalyzeState();
}

class _TabAnalyzeState extends State<TabAnalyze> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Analyze',
        style: TextStyle(
          fontSize: 60,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
