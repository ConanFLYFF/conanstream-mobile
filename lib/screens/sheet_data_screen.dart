import 'package:flutter/material.dart';
import '../services/sheet_service.dart';

class SheetDataScreen extends StatefulWidget {
  const SheetDataScreen({super.key});

  @override
  State<SheetDataScreen> createState() => _SheetDataScreenState();
}

class _SheetDataScreenState extends State<SheetDataScreen> {
  late Future<List<dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = SheetService.fetchSheetData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Données du Google Sheet'),
        backgroundColor: const Color(0xFF030509),
      ),
      backgroundColor: const Color(0xFF030509),
      body: FutureBuilder<List<dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucune donnée trouvée.', style: TextStyle(color: Colors.white70)));
          }

          final rows = snapshot.data!;

          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              // row est une Map contenant tes en-têtes de colonnes (ex: row['nom'], row['statut'], etc.)
              return Card(
                color: const Color(0xFF121824),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(
                    row.values.isNotEmpty ? row.values.first.toString() : 'Ligne ${index + 1}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    row.toString(),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}