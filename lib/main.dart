import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/bootstrap/app_composition_root.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final compositionRoot = AppCompositionRoot.defaults();

  runApp(
    BudgetAccountingApp(
      services: compositionRoot.services,
      onDispose: compositionRoot.close,
    ),
  );
}
