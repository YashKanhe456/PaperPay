import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';

class DashboardPlaceholder extends StatelessWidget {
  const DashboardPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.dashboardTitle),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'PaperPay app structure is ready.\nDashboard screens come next.',
            ),
          ),
        ),
      ),
    );
  }
}
