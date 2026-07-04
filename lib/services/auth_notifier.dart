import 'package:flutter/material.dart';

class AuthRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final authRefreshNotifier = AuthRefreshNotifier();
