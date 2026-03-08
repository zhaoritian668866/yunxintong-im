import 'package:flutter/material.dart';

enum AppRole { user, saasAdmin, enterpriseAdmin }

class AppState extends ChangeNotifier {
  AppRole _currentRole = AppRole.user;
  bool _isLoggedIn = false;
  String _enterpriseId = '';
  String _enterpriseName = '';
  String _userName = '';

  AppRole get currentRole => _currentRole;
  bool get isLoggedIn => _isLoggedIn;
  String get enterpriseId => _enterpriseId;
  String get enterpriseName => _enterpriseName;
  String get userName => _userName;

  void login(String name) {
    _isLoggedIn = true;
    _userName = name;
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    _enterpriseId = '';
    _enterpriseName = '';
    _userName = '';
    _currentRole = AppRole.user;
    notifyListeners();
  }

  void setEnterprise(String id, String name) {
    _enterpriseId = id;
    _enterpriseName = name;
    notifyListeners();
  }

  void switchRole(AppRole role) {
    _currentRole = role;
    notifyListeners();
  }
}
