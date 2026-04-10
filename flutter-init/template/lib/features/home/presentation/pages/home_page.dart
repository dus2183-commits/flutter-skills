import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('{{TAB_1_NAME}}')),
      body: const Center(
        child: Text('Home Tab\n\n这里是首页占位\n用 flutter-flow-feature 生成业务模块'),
      ),
    );
  }
}
