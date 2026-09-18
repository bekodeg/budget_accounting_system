import 'package:flutter/foundation.dart';

import 'app_section.dart';

final class AppNavigationController extends ChangeNotifier {
  AppNavigationController({
    AppSection initialSection = AppSection.transactions,
  }) : _section = initialSection;

  AppSection _section;

  AppSection get section => _section;

  void select(AppSection section) {
    if (_section == section) {
      return;
    }

    _section = section;
    notifyListeners();
  }
}
