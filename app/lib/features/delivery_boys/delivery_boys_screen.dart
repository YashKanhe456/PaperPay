import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_colors.dart';
import 'delivery_boy_provider.dart';
import 'add_delivery_boy_screen.dart';

class DeliveryBoysScreen extends ConsumerStatefulWidget {
  const DeliveryBoysScreen({super.key});

  @override
  ConsumerState<DeliveryBoysScreen> createState() => _DeliveryBoysScreenState();
}

class _DeliveryBoysScreenState extends ConsumerState<DeliveryBoysScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deliveryBoyProvider.notifier).load();
    });
  }

  Future<void> _confirmDelete(DeliveryBoyModel boy) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Delivery Boy?'),
        content: Text('"${boy.name}" ko delete karna chahte hain?'),
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
      await ref.read(deliveryBoyProvider.notifier).delete(boy.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deliveryBoyProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Delivery Boys', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => ref.read(deliveryBoyProvider.notifier).load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Add Delivery Boy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: () async {
          await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(builder: (_) => const AddDeliveryBoyScreen()),
          );
          if (mounted) ref.read(deliveryBoyProvider.notifier).load();
        },
      ),
      body: state.isLoading
          ? _buildShimmer()
          : state.deliveryBoys.isEmpty
              ? _buildEmpty(state.error)
              : RefreshIndicator(
                  color: AppColors.secondary,
                  onRefresh: () => ref.read(deliveryBoyProvider.notifier).load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: state.deliveryBoys.length,
                    itemBuilder: (BuildContext context, int i) => _DeliveryBoyCard(
                      boy: state.deliveryBoys[i],
                      onDelete: () => _confirmDelete(state.deliveryBoys[i]),
                    ),
                  ),
                ),
    );
  }

  Widget _buildShimmer() => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 5,
          itemBuilder: (BuildContext context, int index) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 100,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          ),
        ),
      );

  Widget _buildEmpty(String? error) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delivery_dining_rounded, size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(error ?? 'Koi delivery boy nahi mila.\nPehla boy add karein.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black54)),
          ],
        ),
      );
}

class _DeliveryBoyCard extends StatelessWidget {
  const _DeliveryBoyCard({required this.boy, required this.onDelete});
  final DeliveryBoyModel boy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final progress = boy.totalToday > 0 ? boy.deliveredToday / boy.totalToday : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(boy.name[0].toUpperCase(),
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(boy.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    if (boy.phone != null)
                      Text(boy.phone!, style: const TextStyle(color: Colors.black45, fontSize: 13)),
                  ],
                ),
              ),
              if (boy.area != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(boy.area!, style: const TextStyle(fontSize: 12, color: AppColors.secondary, fontWeight: FontWeight.w700)),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 22),
                onPressed: onDelete,
              ),
            ],
          ),
          if (boy.totalToday > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      color: AppColors.success,
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${boy.deliveredToday}/${boy.totalToday}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
