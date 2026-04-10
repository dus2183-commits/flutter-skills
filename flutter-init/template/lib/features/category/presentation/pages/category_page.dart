import 'package:flutter/material.dart';

class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('{{TAB_2_NAME}}')),
      body: const Center(child: Text('Category Tab')),
    );
  }
}
