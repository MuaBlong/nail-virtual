import 'package:flutter/material.dart';
import '../widgets/nail_catalog.dart';
import 'try_nail.dart';

class NailSetsScreen extends StatelessWidget {
  const NailSetsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bộ mẫu Nail')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: NailCatalog(
        onSelect: (set) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TryNailScreen(nailSet: set)),
        ),
      ),
    ),
  );
}
