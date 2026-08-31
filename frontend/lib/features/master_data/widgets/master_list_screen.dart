import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Generic list screen used by every master data module.
/// [title]       — page heading
/// [items]       — the list of items (or AsyncValue)
/// [itemBuilder] — builds a row for each item
/// [onAdd]       — opens the add form
class MasterListScreen<T> extends StatelessWidget {
  final String title;
  final AsyncValue<List<T>> items;
  final Widget Function(T item) itemBuilder;
  final VoidCallback onAdd;
  final VoidCallback onRefresh;

  const MasterListScreen({
    super.key,
    required this.title,
    required this.items,
    required this.itemBuilder,
    required this.onAdd,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: onRefresh),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: switch (items) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError(:final error) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 8),
                Text('Error: $error'),
                const SizedBox(height: 12),
                FilledButton(onPressed: onRefresh, child: const Text('Retry')),
              ],
            ),
          ),
        AsyncData(:final value) => value.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.inbox, size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    const Text('No records yet'),
                    const SizedBox(height: 12),
                    FilledButton.tonal(onPressed: onAdd, child: const Text('Add first one')),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: value.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (ctx, i) => itemBuilder(value[i]),
              ),
        _ => const SizedBox(),
      },
    );
  }
}
