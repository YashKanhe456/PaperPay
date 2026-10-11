import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../newspapers/newspaper_provider.dart';
import 'subscription_provider.dart';

class AddSubscriptionScreen extends ConsumerStatefulWidget {
  const AddSubscriptionScreen({required this.customerId, super.key});

  final String customerId;

  @override
  ConsumerState<AddSubscriptionScreen> createState() => _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends ConsumerState<AddSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _rateController = TextEditingController();
  String? _selectedNewspaperId;
  String _planType = 'monthly';

  static const _planTypes = ['monthly', 'quarterly', 'yearly'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(newspaperProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedNewspaperId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Newspaper select karein'), backgroundColor: AppColors.danger),
      );
      return;
    }

    final ok = await ref.read(subscriptionProvider.notifier).add(
          customerId: widget.customerId,
          newspaperId: _selectedNewspaperId!,
          rate: double.parse(_rateController.text),
          planType: _planType,
        );

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription add ho gaya ✓'), backgroundColor: AppColors.success),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final newspapers = ref.watch(newspaperProvider).newspapers;
    final subState = ref.watch(subscriptionProvider);

    // Auto-fill rate from selected newspaper
    if (_selectedNewspaperId != null && _rateController.text.isEmpty) {
      final selected = newspapers.where((n) => n.id == _selectedNewspaperId).firstOrNull;
      if (selected != null) {
        _rateController.text = selected.sellingPrice.toStringAsFixed(0);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Add Subscription', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label('Newspaper *'),
              newspapers.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Koi newspaper nahi mila. Pehle newspaper add karein.'),
                    )
                  : DropdownButtonFormField<String>(
                      initialValue: _selectedNewspaperId,
                      decoration: _inputDecoration('Newspaper chunein'),
                      items: newspapers
                          .map((n) => DropdownMenuItem(
                                value: n.id,
                                child: Text('${n.name} — ${Formatters.formatCurrency(n.sellingPrice)}/mo'),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedNewspaperId = v;
                          // Auto-fill rate from newspaper
                          final n = newspapers.where((n) => n.id == v).firstOrNull;
                          if (n != null) {
                            _rateController.text = n.sellingPrice.toStringAsFixed(0);
                          }
                        });
                      },
                    ),
              const SizedBox(height: 16),
              _label('Monthly Rate (₹) *'),
              TextFormField(
                controller: _rateController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('e.g. 150'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Rate required';
                  if (double.tryParse(v) == null) return 'Valid amount darj karein';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _label('Plan Type'),
              DropdownButtonFormField<String>(
                initialValue: _planType,
                decoration: _inputDecoration('Plan chunein'),
                items: _planTypes
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase())))
                    .toList(),
                onChanged: (v) => setState(() => _planType = v ?? 'monthly'),
              ),
              if (subState.error != null) ...[
                const SizedBox(height: 16),
                Text(subState.error!, style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: 28),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: subState.isSaving ? null : _submit,
                child: subState.isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Subscription', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}
