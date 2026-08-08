import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmergencyContact {
  String name;
  String relation;
  String phone;

  EmergencyContact({
    required this.name,
    required this.relation,
    required this.phone,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'relation': relation,
        'phone': phone,
      };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) => EmergencyContact(
        name: json['name'] as String? ?? '',
        relation: json['relation'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
      );
}

class UserAccount {
  String fullName;
  String email;
  String password;
  String mobileNumber;
  String dateOfBirth;
  String bloodGroup;
  List<EmergencyContact> emergencyContacts;

  UserAccount({
    required this.fullName,
    required this.email,
    required this.password,
    required this.mobileNumber,
    required this.dateOfBirth,
    required this.bloodGroup,
    required this.emergencyContacts,
  });

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'email': email,
        'password': password,
        'mobileNumber': mobileNumber,
        'dateOfBirth': dateOfBirth,
        'bloodGroup': bloodGroup,
        'emergencyContacts': emergencyContacts.map((c) => c.toJson()).toList(),
      };

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
        fullName: json['fullName'] as String? ?? '',
        email: json['email'] as String? ?? '',
        password: json['password'] as String? ?? '',
        mobileNumber: json['mobileNumber'] as String? ?? '',
        dateOfBirth: json['dateOfBirth'] as String? ?? '',
        bloodGroup: json['bloodGroup'] as String? ?? 'O+',
        emergencyContacts: (json['emergencyContacts'] as List<dynamic>?)
                ?.map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class UserState extends ChangeNotifier {
  static final UserState instance = UserState._internal();
  factory UserState() => instance;

  UserState._internal() {
    _seedDefaultUser();
  }

  final Map<String, UserAccount> _registeredUsers = {};
  UserAccount? _currentUser;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _currentUser != null;
  UserAccount? get currentUser => _currentUser;

  String get name => _currentUser?.fullName ?? 'Guest';
  String get phone => _currentUser?.mobileNumber ?? '';
  String get email => _currentUser?.email ?? '';
  String get dateOfBirth => _currentUser?.dateOfBirth ?? '';
  String get bloodGroup => _currentUser?.bloodGroup ?? '';
  List<EmergencyContact> get emergencyContacts => _currentUser?.emergencyContacts ?? [];

  void _seedDefaultUser() {
    final defaultUser = UserAccount(
      fullName: 'Alex Mercer',
      email: 'alex@example.com',
      password: 'password123',
      mobileNumber: '+919876543210',
      dateOfBirth: '1998-05-14',
      bloodGroup: 'O+',
      emergencyContacts: [
        EmergencyContact(name: 'Sarah Mercer', relation: 'Sister', phone: '+919876543211'),
        EmergencyContact(name: 'David Chen', relation: 'Spouse', phone: '+919876543212'),
      ],
    );
    _registeredUsers[defaultUser.email.toLowerCase()] = defaultUser;
  }

  /// Loads saved users and active session from persistent SharedPreferences
  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJsonStr = prefs.getString('saved_registered_users');
      if (usersJsonStr != null && usersJsonStr.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(usersJsonStr);
        decoded.forEach((key, val) {
          _registeredUsers[key] = UserAccount.fromJson(val as Map<String, dynamic>);
        });
      }

      final activeEmail = prefs.getString('active_user_session_email');
      if (activeEmail != null && activeEmail.isNotEmpty) {
        final cleanEmail = activeEmail.trim().toLowerCase();
        if (_registeredUsers.containsKey(cleanEmail)) {
          _currentUser = _registeredUsers[cleanEmail];
        }
      }
    } catch (e) {
      debugPrint('Error loading user state from storage: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Persists current users and active session to SharedPreferences
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> exportUsers = {};
      _registeredUsers.forEach((key, user) {
        exportUsers[key] = user.toJson();
      });
      await prefs.setString('saved_registered_users', jsonEncode(exportUsers));

      if (_currentUser != null) {
        await prefs.setString('active_user_session_email', _currentUser!.email.toLowerCase());
      } else {
        await prefs.remove('active_user_session_email');
      }
    } catch (e) {
      debugPrint('Error saving user state to storage: $e');
    }
  }

  /// Register a new user with email uniqueness check and persistent storage
  String? registerUser({
    required String fullName,
    required String email,
    required String password,
    required String mobileNumber,
    required String dateOfBirth,
    required String bloodGroup,
    required List<EmergencyContact> emergencyContacts,
  }) {
    final cleanEmail = email.trim().toLowerCase();
    if (_registeredUsers.containsKey(cleanEmail)) {
      return 'An account with this email address already exists.';
    }

    final newUser = UserAccount(
      fullName: fullName.trim(),
      email: cleanEmail,
      password: password,
      mobileNumber: mobileNumber.trim(),
      dateOfBirth: dateOfBirth,
      bloodGroup: bloodGroup,
      emergencyContacts: List.from(emergencyContacts),
    );

    _registeredUsers[cleanEmail] = newUser;
    _currentUser = newUser;
    _saveToStorage();
    notifyListeners();
    return null; // Success
  }

  /// Authenticate against registered users and save active session
  String? loginUser({required String email, required String password}) {
    final cleanEmail = email.trim().toLowerCase();
    if (!_registeredUsers.containsKey(cleanEmail)) {
      return 'No account found with this email address. Please register first.';
    }

    final user = _registeredUsers[cleanEmail]!;
    if (user.password != password) {
      return 'Incorrect password. Please try again.';
    }

    _currentUser = user;
    _saveToStorage();
    notifyListeners();
    return null; // Success
  }

  /// Logout active session and remove active session token from persistent storage
  void logout() {
    _currentUser = null;
    _saveToStorage();
    notifyListeners();
  }

  void updateUserProfile({
    required String newName,
    required String newPhone,
    required String newEmail,
    required String newDob,
    required String newBloodGroup,
    required List<EmergencyContact> newContacts,
  }) {
    if (_currentUser != null) {
      _currentUser!.fullName = newName;
      _currentUser!.mobileNumber = newPhone;
      _currentUser!.email = newEmail;
      _currentUser!.dateOfBirth = newDob;
      _currentUser!.bloodGroup = newBloodGroup;
      _currentUser!.emergencyContacts = List.from(newContacts);
      _saveToStorage();
      notifyListeners();
    }
  }

  List<String> getEmergencyPhoneNumbers() {
    return emergencyContacts
        .map((c) => c.phone.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }
}
