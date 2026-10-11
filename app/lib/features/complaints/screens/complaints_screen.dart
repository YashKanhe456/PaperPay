import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/utils/formatters.dart';

// ─── Model ───────────────────────────────────────────────────────────────────

class ComplaintModel {
  const ComplaintModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.category,
    required this.description,
    required this.status,
    required this.createdAt,
    this.photoUrl,
    this.notes,
    this.resolvedAt,
  });

  factory ComplaintModel.fromJson(Map<String, dynamic> json) {
    return ComplaintModel(
      id: json['id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? 'Customer',
      category: json['category']?.toString() ?? 'general',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      photoUrl: json['photo_url']?.toString(),
      notes: json['notes']?.toString(),
      resolvedAt: json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at'] as String) : null,
    );
  }

  final String id;
  final String customerId;
  final String customerName;
  final String category;
  final String description;
  final String status;
  final DateTime createdAt;
  final String? photoUrl;
  final String? notes;
  final DateTime? resolvedAt;

  int get daysSince => DateTime.now().difference(createdAt).inDays;
}

// ─── Provider ────────────────────────────────────────────────────────────────

class _ComplaintState {
  const _ComplaintState({
    this.complaints = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.filter = 'All',
    this.error,
  });
  final List<ComplaintModel> complaints;
  final bool isLoading;
  final bool isSaving;
  final String filter;
  final String? error;
  _ComplaintState copyWith({
    List<ComplaintModel>? complaints,
    bool? isLoading,
    bool? isSaving,
    String? filter,
    String? error,
    bool clearError = false,
  }) =>
      _ComplaintState(
        complaints: complaints ?? this.complaints,
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        filter: filter ?? this.filter,
        error: clearError ? null : error ?? this.error,
      );
}

// REFACTORED TO Notifier to resolve "StateNotifier not found" issues on Chrome
class _ComplaintNotifier extends Notifier<_ComplaintState> {
  @override
  _ComplaintState build() {
    return const _ComplaintState();
  }

  ApiService get _api => ref.read(apiServiceProvider);

  Future<void> load() async {
    final agencyId = SessionService.agencyId;
    if (agencyId == null || agencyId.isEmpty) {
      state = state.copyWith(error: 'Please logout and login again');
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/customer-app/complaints',
        queryParameters: {'agency_id': agencyId},
        options: await _api.authOptions(),
      ).timeout(ApiService.requestTimeout);
      final list = (res.data?['complaints'] as List<dynamic>? ?? [])
          .map((dynamic e) => ComplaintModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(complaints: list, isLoading: false);
    } on DioException catch (error) {
      state = state.copyWith(isLoading: false, error: _message(error, 'Complaints load nahi hue.'));
    }
  }

  Future<bool> updateStatus(String id, String status, String? notes) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _api.dio.put<Map<String, dynamic>>(
        '/customer-app/complaints/$id',
        data: {'status': status, if (notes != null) 'notes': notes},
        options: await _api.authOptions(),
      ).timeout(ApiService.requestTimeout);
      state = state.copyWith(isSaving: false);
      await load();
      return true;
    } on DioException catch (error) {
      state = state.copyWith(isSaving: false, error: _message(error, 'Update nahi hua.'));
      return false;
    }
  }

  void setFilter(String filter) {
    state = state.copyWith(filter: filter);
  }

  String _message(DioException error, String fallback) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Request timed out. Please try again.';
    }
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return fallback;
  }
}

final _complaintProvider = NotifierProvider.autoDispose<_ComplaintNotifier, _ComplaintState>(() {
  return _ComplaintNotifier();
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class ComplaintsScreen extends ConsumerStatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  ConsumerState<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends ConsumerState<ComplaintsScreen> {
  static const _filters = ['All', 'Open', 'In Progress', 'Resolved'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(_complaintProvider.notifier).load();
    });
  }

  List<ComplaintModel> _filtered(List<ComplaintModel> all, String filter) {
    switch (filter) {
      case 'Open':
        return all.where((c) => c.status == 'open').toList();
      case 'In Progress':
        return all.where((c) => c.status == 'in_progress').toList();
      case 'Resolved':
        return all.where((c) => c.status == 'resolved').toList();
      default:
        return all;
    }
  }

  void _showDetail(ComplaintModel complaint) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComplaintDetailSheet(
        complaint: complaint,
        onUpdate: (status, notes) => ref.read(_complaintProvider.notifier).updateStatus(complaint.id, status, notes),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_complaintProvider);
    final filtered = _filtered(state.complaints, state.filter);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Complaints', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => ref.read(_complaintProvider.notifier).load(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: _filters.map((f) {
                final selected = f == state.filter;
                return GestureDetector(
                  onTap: () => ref.read(_complaintProvider.notifier).setFilter(f),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: selected ? AppColors.primary : Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected) ...[
                          const Icon(Icons.check, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                        ],
                        Text(f,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: selected ? Colors.white : Colors.black54)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: state.isLoading
                ? _buildShimmer()
                : filtered.isEmpty
                    ? _buildEmpty(state.error)
                    : RefreshIndicator(
                        color: AppColors.secondary,
                        onRefresh: () => ref.read(_complaintProvider.notifier).load(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) => _ComplaintCard(
                            complaint: filtered[i],
                            onTap: () => _showDetail(filtered[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 100,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }

  Widget _buildEmpty(String? error) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 64, color: AppColors.success.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(error ?? 'Koi complaint nahi hai 🎉',
                style: const TextStyle(fontSize: 16, color: Colors.black54)),
          ],
        ),
      );
}

// ─── Complaint Card ───────────────────────────────────────────────────────────

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({required this.complaint, required this.onTap});
  final ComplaintModel complaint;
  final VoidCallback onTap;

  Color _statusColor(String s) {
    switch (s) {
      case 'open':
        return AppColors.danger;
      case 'in_progress':
        return AppColors.warning;
      case 'resolved':
        return AppColors.success;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'open':
        return 'Open';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(complaint.status);
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                Expanded(
                  child: Text(complaint.customerName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(_statusLabel(complaint.status),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(complaint.category.toUpperCase(),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.secondary)),
                ),
                const SizedBox(width: 8),
                Text('${complaint.daysSince} din pehle',
                    style: const TextStyle(fontSize: 12, color: Colors.black45)),
              ],
            ),
            const SizedBox(height: 8),
            Text(complaint.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ─── Detail Bottom Sheet ──────────────────────────────────────────────────────

class _ComplaintDetailSheet extends ConsumerStatefulWidget {
  const _ComplaintDetailSheet({required this.complaint, required this.onUpdate});
  final ComplaintModel complaint;
  final Future<bool> Function(String status, String? notes) onUpdate;

  @override
  ConsumerState<_ComplaintDetailSheet> createState() => _ComplaintDetailSheetState();
}

class _ComplaintDetailSheetState extends ConsumerState<_ComplaintDetailSheet> {
  late String _selectedStatus;
  final _notesController = TextEditingController();
  bool _isSaving = false;

  static const _statuses = ['open', 'in_progress', 'resolved'];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.complaint.status;
    _notesController.text = widget.complaint.notes ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final ok = await widget.onUpdate(_selectedStatus, _notesController.text.trim().isEmpty ? null : _notesController.text.trim());
    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.complaint;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(c.customerName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${c.category.toUpperCase()} · ${Formatters.formatDate(c.createdAt)}',
                style: const TextStyle(color: Colors.black45, fontSize: 13)),
            const SizedBox(height: 16),
            const Text('Description', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(c.description, style: const TextStyle(color: Colors.black54)),
            if (c.photoUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(c.photoUrl!, height: 160, fit: BoxFit.cover),
              ),
            ],
            const SizedBox(height: 20),
            const Text('Status Update Karein', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              items: _statuses
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' ').toUpperCase())))
                  .toList(),
              onChanged: (v) => setState(() => _selectedStatus = v ?? _selectedStatus),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Notes (optional)',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Update', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
