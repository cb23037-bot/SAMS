import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/api_service.dart';

/// Central state controller for the entire SAMS application.
///
/// This class acts as the single source of truth for authentication state.
/// It extends [ChangeNotifier] so that any widget listening to it will
/// automatically rebuild when the user logs in, logs out, or updates profile.
///
/// Usage: provided at the root of the widget tree via [ChangeNotifierProvider],
/// then accessed in child widgets using [Provider.of] or [context.watch].
class AppController extends ChangeNotifier {
  /// Requires an [ApiService] instance to be injected — this keeps
  /// network logic separate from state logic (separation of concerns).
  AppController({required ApiService apiService}) : _apiService = apiService {
    ApiService.onUnauthorized = signOut;
  }

  // ── Private fields ──────────────────────────────────────────────────────────

  /// The API service used for all network requests.
  final ApiService _apiService;

  // ── Public state ────────────────────────────────────────────────────────────

  /// The currently logged-in user. Null means no one is logged in.
  AppUser? currentUser;

  /// The Bearer token returned by the backend after a successful login.
  /// Null means the user is not authenticated.
  String? _token;

  /// True while an async operation (login, logout, profile update) is running.
  /// Used by the UI to show loading indicators and disable buttons.
  bool isLoading = false;

  // ── Computed getters ────────────────────────────────────────────────────────

  /// Returns true only when both a user object AND a token are present.
  /// Both must exist because the token is needed for every API call.
  bool get isAuthenticated => currentUser != null && _token != null;

  /// Exposes the token so pages can pass it to [ApiService] calls.
  String? get token => _token;

  /// Exposes the API service so pages can call endpoints directly
  /// without needing their own reference.
  ApiService get apiService => _apiService;

  // ── Methods ─────────────────────────────────────────────────────────────────

  /// Logs the user in with [email] and [password].
  ///
  /// The [role] parameter is compared against the role returned by the API.
  /// If they don't match (e.g., a student trying to log in as Pusat Adab),
  /// an exception is thrown and the login is rejected locally before any
  /// session is stored.
  ///
  /// On success, [currentUser] and [_token] are populated and listeners
  /// are notified to trigger a UI rebuild (e.g., navigate to home page).
  Future<void> signIn({
    required String role,
    required String email,
    required String password,
  }) async {
    isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.login(email: email, password: password);

      // Reject login if the role selected on the login screen doesn't match
      // the role stored in the database for this account.
      if (response.user.role != role) {
        throw Exception('The selected role does not match this account.');
      }

      currentUser = response.user;
      _token = response.token;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Updates the currently logged-in student's editable profile fields.
  ///
  /// [fields] is a map of only the fields that changed (e.g., phone_number,
  /// current_semester). The backend returns the full updated user object
  /// which replaces [currentUser] so the UI always shows fresh data.
  Future<void> updateProfile(Map<String, dynamic> fields) async {
    isLoading = true;
    notifyListeners();

    try {
      final updated = await _apiService.updateProfile(
        token: _token!,
        fields: fields,
      );
      currentUser = updated;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Logs the user out by revoking the token on the backend and clearing
  /// local session data.
  ///
  /// The API call is wrapped in try-catch because if the server is
  /// unreachable (e.g., no internet), we still want to clear the local
  /// session so the user is not stuck on the home page with a stale token.
  Future<void> signOut() async {
    final token = _token;

    isLoading = true;
    notifyListeners();

    try {
      if (token != null) {
        await _apiService.logout(token: token);
      }
    } catch (_) {
      // Even if the API is unavailable, we still clear the local session.
    } finally {
      currentUser = null;
      _token = null;
      isLoading = false;
      notifyListeners();
    }
  }
}
