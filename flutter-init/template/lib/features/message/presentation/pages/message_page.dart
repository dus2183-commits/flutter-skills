import 'package:flutter/material.dart';

class MessagePage extends StatelessWidget {
  const MessagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('{{TAB_4_NAME}}')),
      body: const Center(child: Text('Message Tab')),
    );
  }
}
