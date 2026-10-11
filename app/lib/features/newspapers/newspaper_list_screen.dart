import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import 'newspaper_provider.dart';
import 'add_newspaper_screen.dart';

class NewspaperListScreen extends ConsumerStatefulWidget {
  const NewspaperListScreen({super.key});

  @override
  ConsumerState<NewspaperListScreen> createState() => _NewspaperListScreenState();
}

class _NewspaperListScreenState extends ConsumerState<NewspaperListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(newspaperProvider.notifier).load();
    });
  }

  Future<void> _confirmDelete(NewspaperModel newspaper) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Newspaper Delete Karein?'),
        content: Text('"${newspaper.name}" ko inactive kar diya jaayega.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(newspaperProvider.notifier).softDelete(newspaper.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(newspaperProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Newspapers', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(newspaperProvider.notifier).load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Newspaper', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: () async {
          await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(builder: (_) => const AddNewspaperScreen()),
          );
          if (mounted) ref.read(newspaperProvider.notifier).load();
        },
      ),
      body: state.isLoading
          ? _buildShimmer()
          : state.newspapers.isEmpty
              ? _buildEmpty(state.error)
              : RefreshIndicator(
                  color: AppColors.secondary,
                  onRefresh: () => ref.read(newspaperProvider.notifier).load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: state.newspapers.length,
                    itemBuilder: (BuildContext context, int i) => _NewspaperCard(
                      newspaper: state.newspapers[i],
                      onDelete: () => _confirmDelete(state.newspapers[i]),
                    ),
                  ),
                ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (BuildContext context, int index) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 90,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }

  Widget _buildEmpty(String? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.newspaper_rounded, size: 64, color: AppColors.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              error ?? 'Koi newspaper nahi mila.\nPehla newspaper add karein.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewspaperCard extends StatelessWidget {
  const _NewspaperCard({required this.newspaper, required this.onDelete});

  final NewspaperModel newspaper;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.newspaper_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(newspaper.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _Chip(
                      label: newspaper.type.toUpperCase(),
                      color: AppColors.secondary,
                    ),
                    if (newspaper.language != null) ...[
                      const SizedBox(width: 6),
                      _Chip(label: newspaper.language!, color: AppColors.primary),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${Formatters.formatCurrency(newspaper.sellingPrice)}/mo · ${newspaper.activeSubscribers} subscribers',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
