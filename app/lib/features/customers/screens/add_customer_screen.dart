import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/customer_model.dart';
import '../providers/customer_provider.dart';

class AddCustomerScreen extends ConsumerStatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _areaController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _altContactController = TextEditingController();
  final _notesController = TextEditingController();
  String _category = 'New';
  final Map<String, bool> _selectedNewspapers = {
    for (final item in CustomerNotifier.availableNewspapers) item.id: false,
  };
  final Map<String, TextEditingController> _rateControllers = {
    for (final item in CustomerNotifier.availableNewspapers)
      item.id: TextEditingController(),
  };

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _areaController.dispose();
    _landmarkController.dispose();
    _altContactController.dispose();
    _notesController.dispose();
    for (final controller in _rateControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Add Customer')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _buildField(
                controller: _nameController,
                label: 'Name',
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Name required hai' : null,
              ),
              const SizedBox(height: 12),
              _PhoneField(controller: _phoneController, label: 'Phone'),
              const SizedBox(height: 12),
              _buildField(controller: _emailController, label: 'Email'),
              const SizedBox(height: 12),
              _buildField(controller: _addressController, label: 'Address', maxLines: 3),
              const SizedBox(height: 12),
              _buildField(controller: _areaController, label: 'Area'),
              const SizedBox(height: 12),
              _buildField(controller: _landmarkController, label: 'Landmark'),
              const SizedBox(height: 12),
              _PhoneField(controller: _altContactController, label: 'Alt Contact', required: false),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                items: const ['New', 'Regular', 'VIP', 'Risky']
                    .map((category) => DropdownMenuItem(value: category, child: Text(category)))
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _category = value;
                  });
                },
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 12),
              _buildField(controller: _notesController, label: 'Notes', maxLines: 4),
              const SizedBox(height: 24),
              const Text(
                'Newspaper Subscriptions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ...CustomerNotifier.availableNewspapers.map(_buildNewspaperTile),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                  onPressed: state.isSaving ? null : _saveCustomer,
                  child: Text(state.isSaving ? 'Saving...' : 'Save Customer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, alignLabelWithHint: maxLines > 1),
    );
  }

  Widget _buildNewspaperTile(NewspaperOption option) {
    final selected = _selectedNewspapers[option.id] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: selected,
            activeColor: AppColors.secondary,
            onChanged: (value) {
              setState(() {
                _selectedNewspapers[option.id] = value ?? false;
              });
            },
            title: Text(
              option.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (selected)
            TextFormField(
              controller: _rateControllers[option.id],
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Monthly Rate',
                prefixText: '\u20B9 ',
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final phone = _phoneController.text.trim();
    if (Validators.isValidIndianPhone(phone) != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valid 10 digit phone dijiye')),
      );
      return;
    }

    final agencyId = ref.read(authProvider).currentUser?.agencyId;
    if (agencyId == null || agencyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agency nahi mili')),
      );
      return;
    }

    final subscriptions = CustomerNotifier.availableNewspapers
        .where((item) => _selectedNewspapers[item.id] == true)
        .map((item) => {
              'newspaper_id': item.id,
              'rate': double.tryParse(_rateControllers[item.id]!.text.trim()) ?? 0,
            })
        .toList();

    final success = await ref.read(customerProvider.notifier).createCustomer(
          payload: {
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'agency_id': agencyId,
            'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
            'address':
                _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
            'area': _areaController.text.trim().isEmpty ? null : _areaController.text.trim(),
            'landmark':
                _landmarkController.text.trim().isEmpty ? null : _landmarkController.text.trim(),
            'alt_contact': _altContactController.text.trim().isEmpty
                ? null
                : _altContactController.text.trim(),
            'category': _category,
            'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            'subscriptions': subscriptions,
          },
        );

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.of(context).pop();
      return;
    }

    final message = ref.read(customerProvider).error ?? 'Customer save nahi ho paaya';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    required this.label,
    this.required = true,
  });

  final TextEditingController controller;
  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      maxLength: 10,
      decoration: InputDecoration(
        labelText: label,
        prefixText: '+91 ',
        counterText: '',
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (!required && text.isEmpty) {
          return null;
        }
        if (!Validators.isValidIndianPhone(text)) {
          return '10 digit phone dijiye';
        }
        return null;
      },
    );
  }
}
