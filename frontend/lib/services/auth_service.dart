import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  final ApiService _apiService;
  static const String _tokenKey = 'studentstay_auth_token';

  String? _token;
  User? _currentUser;
  bool _isLoading = false;
  String? _authError;

  AuthService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  String? get token => _token;
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get authError => _authError;

  bool get isAuthenticated => _token != null && _currentUser != null;
  bool get isOwner => _currentUser?.isOwner ?? false;
  bool get isStudent => _currentUser?.isStudent ?? false;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  /// Restores session on app startup if a saved token exists.
  Future<void> restoreSession() async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_tokenKey);

      if (savedToken != null && savedToken.isNotEmpty) {
        _token = savedToken;
        try {
          _currentUser = await _apiService.getMe(token: savedToken);
        } catch (_) {
          // Token expired or invalid
          await prefs.remove(_tokenKey);
          _token = null;
          _currentUser = null;
        }
      }
    } catch (e) {
      _authError = 'Error restoring session: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Logs in with email and password.
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    try {
      final accessToken = await _apiService.login(
        email: email.trim(),
        password: password,
      );

      _token = accessToken;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, accessToken);

      _currentUser = await _apiService.getMe(token: accessToken);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _authError = e.toString().replaceFirst('Exception: ', '');
      _token = null;
      _currentUser = null;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Registers a new student or owner account and automatically signs in.
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String role = 'student',
  }) async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    try {
      await _apiService.register(
        name: name.trim(),
        email: email.trim(),
        password: password,
        role: role,
      );

      // Auto login after registration
      return await login(email: email.trim(), password: password);
    } catch (e) {
      _authError = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logs out the user and clears stored credentials.
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (_) {}

    _token = null;
    _currentUser = null;
    _authError = null;
    notifyListeners();
  }

  /// Clears error message manually.
  void clearError() {
    _authError = null;
    notifyListeners();
  }
}
