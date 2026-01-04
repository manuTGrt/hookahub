import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/history/presentation/history_provider.dart';

/// Widget de debug para probar el historial
/// Útil para diagnosticar problemas de carga
class HistoryDebugWidget extends StatelessWidget {
  const HistoryDebugWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HistoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Historial'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: provider.load,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Estado',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRow('isLoading', provider.isLoading.toString()),
                  _buildRow('isLoaded', provider.isLoaded.toString()),
                  _buildRow('error', provider.error ?? 'null'),
                  _buildRow('entries.length', provider.entries.length.toString()),
                  _buildRow('uniqueCount', provider.uniqueCount.toString()),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Entradas',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: provider.entries.map((entry) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ID: ${entry.id}', style: const TextStyle(fontSize: 10)),
                          Text('Mix ID: ${entry.mixId}', style: const TextStyle(fontSize: 10)),
                          Text('Nombre: ${entry.mixName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Autor: ${entry.author}'),
                          Text('Visitado: ${entry.visitedAt}'),
                          Text('Ingredientes: ${entry.ingredients.join(", ")}'),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Agrupado por día',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: provider.groupedByDay.entries.map((group) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${group.key} (${group.value.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          ...group.value.map((e) => Text('  - ${e.mixName}')),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await provider.load();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Recargado: ${provider.entries.length} entradas'),
              ),
            );
          }
        },
        child: const Icon(Icons.play_arrow),
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
