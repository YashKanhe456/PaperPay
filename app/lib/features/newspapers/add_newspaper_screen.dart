import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import 'newspaper_provider.dart';

class AddNewspaperScreen extends ConsumerStatefulWidget {
  const AddNewspaperScreen({super.key});

  @override
  ConsumerState<AddNewspaperScreen> createState() => _AddNewspaperScreenState();
}

class _AddNewspaperScreenState extends ConsumerState<AddNewspaperScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _languageController = TextEditingController();
  final _publisherController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _costPriceController = TextEditingController();
  String _type = 'daily';

  static const _types = ['daily', 'weekly', 'monthly'];
  static const _languages = ['Hindi', 'English', 'Marathi', 'Gujarati', 'Telugu', 'Tamil', 'Kannada', 'Bengali', 'Other'];

  @override
  void dispose() {
    _nameController.dispose();
    _languageController.dispose();
    _publisherController.dispose();
    _sellingPriceController.dispose();
    _costPriceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(newspaperProvider.notifier).add(
          name: _nameController.text.trim(),
          sellingPrice: double.parse(_sellingPriceController.text),
          costPrice: _costPriceController.text.trim().isEmpty
              ? null
              : double.tryParse(_costPriceController.text),
          language: _languageController.text.trim().isEmpty ? null : _languageController.text.trim(),
          type: _type,
          publisher: _publisherController.text.trim().isEmpty ? null : _publisherController.text.trim(),
        );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Newspaper add ho gaya ✓'), backgroundColor: AppColors.success),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(newspaperProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Add Newspaper', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label('Newspaper Name *'),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration('e.g. Times of India'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
              ),
              const SizedBox(height: 16),
              _label('Selling Price (₹/month) *'),
              TextFormField(
                controller: _sellingPriceController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('e.g. 150'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Selling price required';
                  if (double.tryParse(v) == null) return 'Valid number darj karein';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _label('Cost Price (₹/month)'),
              TextFormField(
                controller: _costPriceController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('Optional'),
              ),
              const SizedBox(height: 16),
              _label('Language'),
              DropdownButtonFormField<String>(
                initialValue: _languageController.text.isEmpty ? null : _languageController.text,
                decoration: _inputDecoration('Select language'),
                items: _languages
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => _languageController.text = v ?? '',
              ),
              const SizedBox(height: 16),
              _label('Type'),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: _inputDecoration('Select type'),
                items: _types
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase())))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? 'daily'),
              ),
              const SizedBox(height: 16),
              _label('Publisher'),
              TextFormField(
                controller: _publisherController,
                decoration: _inputDecoration('e.g. Bennett Coleman'),
              ),
              if (state.error != null) ...[
                const SizedBox(height: 16),
                Text(state.error!, style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: 28),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: state.isSaving ? null : _submit,
                child: state.isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Newspaper', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
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
