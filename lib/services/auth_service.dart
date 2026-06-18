import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../firebase_config.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  String? _currentUserEmail;
  String? _currentUserName;
  bool _isLoggedIn = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '461659639574-ocpu70e858d2aue9s2g2l2rdbos8j8at.apps.googleusercontent.com',
  );

  AuthService._internal();

  String? get currentUserEmail => _currentUserEmail;
  String? get currentUserName => _currentUserName;
  bool get isLoggedIn => _isLoggedIn;

  Future<void> checkSavedSession() async {
    if (FirebaseConfig.useFirebase) {
      final user = FirebaseAuth.instance.currentUser;
      _isLoggedIn = user != null;
      _currentUserEmail = user?.email;
      _currentUserName = user?.displayName;
    } else {
      final prefs = await SharedPreferences.getInstance();
      _currentUserEmail = prefs.getString('user_email');
      _currentUserName = prefs.getString('user_name');
      _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    }
  }

  Future<bool> login(String email, String password) async {
    if (FirebaseConfig.useFirebase) {
      try {
        final credential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);
        _currentUserEmail = credential.user?.email;
        _currentUserName = credential.user?.displayName;
        _isLoggedIn = true;
        return true;
      } on FirebaseAuthException catch (e) {
        throw _friendlyAuthError(e.code);
      }
    } else {
      // Mock: allow any valid-looking email with password >= 6 chars
      if (email.contains('@') && password.length >= 6) {
        _currentUserEmail = email;
        _currentUserName = email.split('@')[0]; // Fallback to email prefix
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', email);
        await prefs.setString('user_name', _currentUserName!);
        await prefs.setBool('is_logged_in', true);
        _isLoggedIn = true;
        return true;
      }
      return false;
    }
  }

  Future<bool> signUp(String email, String password, String name) async {
    if (FirebaseConfig.useFirebase) {
      try {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
        await credential.user?.updateDisplayName(name);
        _currentUserEmail = credential.user?.email;
        _currentUserName = name;
        _isLoggedIn = true;
        return true;
      } on FirebaseAuthException catch (e) {
        throw _friendlyAuthError(e.code);
      }
    } else {
      // Mock signup
      if (email.contains('@') && password.length >= 6 && name.isNotEmpty) {
        _currentUserEmail = email;
        _currentUserName = name;
        _isLoggedIn = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', email);
        await prefs.setString('user_name', name);
        await prefs.setBool('is_logged_in', true);
        return true;
      }
      return false;
    }
  }

  Future<bool> loginWithGoogle() async {
    if (FirebaseConfig.useFirebase) {
      try {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          return false; // User cancelled the sign-in flow
        }
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        _currentUserEmail = userCredential.user?.email;
        _currentUserName = userCredential.user?.displayName ?? googleUser.displayName;
        _isLoggedIn = true;
        return true;
      } on FirebaseAuthException catch (e) {
        throw _friendlyAuthError(e.code);
      } catch (e) {
        // Rethrow other errors (e.g. PlatformException / Developer config errors)
        rethrow;
      }
    } else {
      throw Exception('Firebase is disabled. Use mock login instead.');
    }
  }

  Future<bool> loginWithGoogleMock(String email, String name) async {
    _currentUserEmail = email;
    _currentUserName = name;
    _isLoggedIn = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', email);
    await prefs.setString('user_name', name);
    await prefs.setBool('is_logged_in', true);
    return true;
  }

  Future<void> logout() async {
    if (FirebaseConfig.useFirebase) {
      await _googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_email');
      await prefs.remove('user_name');
      await prefs.remove('is_logged_in');
    }
    _currentUserEmail = null;
    _currentUserName = null;
    _isLoggedIn = false;
  }

  String _friendlyAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with that email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait before trying again.';
      case 'email-already-in-use':
        return 'This email address is already registered.';
      case 'weak-password':
        return 'The password is too weak.';
      default:
        return 'Authentication failed ($code). Please try again.';
    }
  }
}
