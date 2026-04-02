/* Auth Service

   This service manages authentication state.

   It handles:
   - tracking the current user role
   - admin login and logout

   When Firebase Auth is added later, only this
   file needs to change.
*/

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  String _role = 'user';

  String get currentRole => _role;

  bool get isAdmin => _role == 'admin';

  void login(String password) {
    if (password == 'apollo123') _role = 'admin';
  }

  void logout() => _role = 'user';
}