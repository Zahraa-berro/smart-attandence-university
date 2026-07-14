import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';

class CreateUserScreen extends StatefulWidget {
  final String role;

  const CreateUserScreen({super.key, required this.role});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  // Student-only
  final _departmentController = TextEditingController();
  final _idController = TextEditingController();
  final ApiService _apiService = ApiService();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isLoadingId = false;
  bool _isLoadingAdminCount = false;
  int _adminCount = 0;

  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  // ── Design tokens ─────────────────────────────────────────────────────────
  static const Color _brand = Color(0xFF1D9E75);
  static const Color _danger = Color(0xFFD85A30);
  static const Color _surface = Color(0xFFF8F7F4);
  static const Color _ink = Color(0xFF1A1A2E);
  static const Color _inkMuted = Color(0xFF888780);

  bool get _isStaff => widget.role == "staff";
  bool get _isAdmin => widget.role == 'admin';
  String get _roleLabel => _isAdmin ? 'Admin' : _isStaff ? 'Staff' : 'Student';
  Color get _accent => _isAdmin
      ? _brand
      : _isStaff
      ? const Color(0xFF5B8DEF)
      : const Color(0xFFEF9F27);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();

    _autoFillStudentId();
    _loadAdminCount();
  }

  // ── Auto-fill student ID ──────────────────────────────────────────────────
  final Map<String, String?> _validationErrors = {
    'name': null,
    'id': null,
    'department': null,
    'phone': null,
    'password': null,
    'email': null,
  };

  Future<void> _loadAdminCount() async {
    if (!_isAdmin) return;

    setState(() => _isLoadingAdminCount = true);
    try {
      final admins = await _apiService.getUsersExt(role: 'admin', includeInactive: true);
      if (!mounted) return;
      setState(() {
        _adminCount = admins.length;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _adminCount = 0;
      });
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingAdminCount = false);
    }
  }

  Future<void> _autoFillStudentId() async {
    if (widget.role != 'student') return;

    setState(() => _isLoadingId = true);

    try {
      final students = await _apiService.getUsersExt(
        role: 'student',
        includeInactive: true,
      );

      const int base = 202610000;
      int maxId = base - 1;

      for (final s in students) {
        final raw = s['studentId'];
        if (raw == null) continue;
        final parsed = int.tryParse(raw.toString());
        if (parsed != null && parsed > maxId) maxId = parsed;
      }

      if (!mounted) return;
      setState(() {
        _idController.text = (maxId + 1).toString();
        _isLoadingId = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _idController.text = '202610000';
        _isLoadingId = false;
      });
    }
  }

  bool _isValidEmail(String email) {
    return email.contains('@') && email.split('@').length == 2 && email.split('@')[1].contains('.');
  }

  bool _isValidPhone(String phone) {
    if (phone.isEmpty) return true; // phone is optional
    final phoneDigits = phone.replaceAll(RegExp(r'[^\d]'), '');
    return phoneDigits.length == 8;
  }

  bool _isValidPassword(String password) {
    final hasLetters = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasNumbers = RegExp(r'\d').hasMatch(password);
    return password.length >= 8 && hasLetters && hasNumbers;
  }

  Future<bool> _emailExists(String email) async {
    final users = await _apiService.getUsersExt(includeInactive: true);
    final normalized = email.toLowerCase().trim();
    return users.any((u) =>
        (u['email'] as String?)?.toLowerCase().trim() == normalized);
  }

  Future<bool> _phoneExists(String phone) async {
    if (phone.isEmpty) return false;
    final users = await _apiService.getUsersExt(includeInactive: true);
    return users.any((u) =>
        (u['phoneNumber'] as String?)?.replaceAll(RegExp(r'[^0-9]'), '') == phone);
  }

  Future<String?> _validateFormAndGetError() async {
    _validationErrors.updateAll((key, value) => null);

    final name = _nameController.text.trim();
    final pass = _passwordController.text.trim();
    final phone = _phoneController.text.trim();
    final department = _departmentController.text.trim();
    final studentId = _idController.text.trim();

    if (name.isEmpty) {
      _validationErrors['name'] = 'Full name is required';
      return 'Full name is required';
    }

    if (widget.role == 'student' && studentId.isEmpty) {
      _validationErrors['id'] = 'Student ID is required';
      return 'Student ID is required';
    }

    if (widget.role == 'student' && department.isEmpty) {
      _validationErrors['department'] = 'Department is required for students';
      return 'Department is required for students';
    }

    if (pass.isEmpty) {
      _validationErrors['password'] = 'Password is required';
      return 'Password is required';
    }

    if (!_isValidPassword(pass)) {
      _validationErrors['password'] = 'Password must be 8+ chars and include letters and numbers';
      return 'Password must be at least 8 characters and include both letters and numbers';
    }

    if (phone.isNotEmpty && !_isValidPhone(phone)) {
      _validationErrors['phone'] = 'Phone must contain exactly 8 digits';
      return 'Phone number must contain exactly 8 digits';
    }

    final email = widget.role == 'student'
        ? '$studentId@std.edu.lb'
        : widget.role == 'staff'
            ? '${name.toLowerCase().replaceAll(' ', '.')}@dc.edu.lb'
            : studentId.isNotEmpty
                ? 'admin$studentId@system.edu'
                : '${name.toLowerCase().replaceAll(' ', '.')}@system.edu';

    if (!_isValidEmail(email)) {
      _validationErrors['email'] = 'Generated email is invalid';
      return 'Invalid email format';
    }

    if (await _emailExists(email)) {
      _validationErrors['email'] = 'Email already belongs to another account';
      return 'Duplicate email detected';
    }

    if (phone.isNotEmpty && await _phoneExists(phone)) {
      _validationErrors['phone'] = 'This phone number is already used';
      return 'Duplicate phone number detected';
    }

    return null;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _idController.dispose();
    super.dispose();
  }

  void _createUser() async {
    final name = _nameController.text.trim();
    final pass = _passwordController.text.trim();
    final phone = _phoneController.text.trim();
    final department = _departmentController.text.trim();

    setState(() => _isLoading = true);
    final validationMessage = await _validateFormAndGetError();
    if (validationMessage != null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack(validationMessage, isError: true);
      return;
    }

    final studentId = _idController.text.trim();
    final email = widget.role == 'student'
        ? '$studentId@std.edu.lb'
        : widget.role == 'staff'
            ? '${name.toLowerCase().replaceAll(' ', '.')}@dc.edu.lb'
            : studentId.isNotEmpty
                ? 'admin$studentId@system.edu'
                : '${name.toLowerCase().replaceAll(' ', '.')}@system.edu';

    try {
      if (widget.role == 'admin') {
        await _apiService.createAdmin(
          name: name,
          email: email,
          password: pass,
          phoneNumber: phone.isEmpty ? null : phone,
          department: department.isEmpty ? 'General' : department,
        );
      } else {
        await _apiService.createUser(
          name: name,
          email: email,
          password: pass,
          role: widget.role == 'staff' ? 'doctor' : 'student',
          phoneNumber: phone.isEmpty ? null : phone,
          studentId: widget.role == 'staff' ? null : studentId,
          department: widget.role == 'staff' ? 'General' : department,
        );
      }
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showSnack("${_roleLabel} account created successfully!");

      _nameController.clear();
      _passwordController.clear();
      _phoneController.clear();
      _departmentController.clear();

      await _autoFillStudentId();
      await _loadAdminCount();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? _danger : _brand,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          // ── Gradient header ──────────────────────────────────────────────
          Container(
            height: 240,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF5DCAA5),
                  Color(0xFF9FE1CB),
                  Color(0xFFF0997B),
                  Color(0xFFD85A30),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.35, 0.70, 1.0],
              ),
            ),
          ),

          // Blob decoration
          Positioned(
            top: -50,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Top bar ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const Spacer(),
                      // Role badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isAdmin
                                  ? Icons.admin_panel_settings_rounded
                                  : _isStaff
                                  ? Icons.school_rounded
                                  : Icons.person_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isAdmin
                                  ? 'Admin'
                                  : (_isStaff ? "Staff" : "Student"),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Hero text ────────────────────────────────────────────────
                FadeTransition(
                  opacity: _fade,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.10),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isAdmin
                                ? Icons.admin_panel_settings_rounded
                                : _isStaff
                                ? Icons.school_rounded
                                : Icons.person_add_rounded,
                            color: _accent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isAdmin
                                  ? 'Create Admin'
                                  : "Create ${_isStaff ? 'Staff' : 'Student'}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              _isAdmin
                                  ? 'Create a new administrator account'
                                  : 'Fill in the details below',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.72),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                if (_isAdmin) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _brand.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.admin_panel_settings_rounded, color: _brand, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total administrators',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF7D7D7D)),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _isLoadingAdminCount ? 'Loading…' : '$_adminCount admins',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: _isLoadingAdminCount ? null : _loadAdminCount,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _brand.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: _isLoadingAdminCount
                                  ? const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF1D9E75)),
                                    )
                                  : const Icon(Icons.refresh_rounded, color: _brand, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── White form sheet ─────────────────────────────────────────
                Expanded(
                  child: SlideTransition(
                    position: _slide,
                    child: FadeTransition(
                      opacity: _fade,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(30),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Drag pill
                            Container(
                              width: 36,
                              height: 4,
                              margin:
                              const EdgeInsets.only(top: 12, bottom: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD3D1C7),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                    20, 16, 20, 40),
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    // ── Full Name ──────────────────────────
                                    _fieldLabel("Full Name"),
                                    _inputField(
                                      controller: _nameController,
                                      hint: "e.g. Ahmed Hassan",
                                      icon: Icons.person_outline_rounded,
                                      keyboardType: TextInputType.name,
                                    ),

                                    const SizedBox(height: 16),

                                    // ── Student ID (students only) ─────────
                                    if (widget.role == 'student') ...[
                                      _fieldLabel("Student ID"),
                                      _inputField(
                                        controller: _idController,
                                        hint: "e.g. 202610000",
                                        icon: Icons.badge_outlined,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        isLoading: _isLoadingId,
                                      ),
                                      const SizedBox(height: 16),
                                    ],

                                    // ── Department (students only) ─────────
                                    if (widget.role != 'staff') ...[
                                      _fieldLabel("Department"),
                                      _inputField(
                                        controller: _departmentController,
                                        hint: "e.g. Computer Science",
                                        icon: Icons.business_outlined,
                                        keyboardType: TextInputType.text,
                                        errorMessage: _validationErrors['department'],
                                      ),
                                      const SizedBox(height: 16),
                                    ],

                                    // ── Phone ──────────────────────────────
                                    _fieldLabel("Phone Number (Optional)"),
                                    _inputField(
                                      controller: _phoneController,
                                      hint: "8 digits only, numbers only",
                                      icon: Icons.phone_outlined,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      errorMessage: _validationErrors['phone'],
                                    ),

                                    const SizedBox(height: 16),

                                    // ── Password ───────────────────────────
                                    _fieldLabel("Password"),
                                    _passwordField(),

                                    const SizedBox(height: 10),

                                    // Info hint
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _accent.withOpacity(0.07),
                                        borderRadius:
                                        BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _accent.withOpacity(0.20),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            color: _accent,
                                            size: 15,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              widget.role == 'student'
                                                  ? 'Email will be automatically generated as: STUDENT_ID@std.edu.lb'
                                                  : 'Email will be automatically generated from name',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _accent,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    if (_validationErrors['email'] != null) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        _validationErrors['email']!,
                                        style: const TextStyle(
                                          color: Color(0xFFD85A30),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 18),

                                    // ── Submit button ──────────────────────
                                    SizedBox(
                                      width: double.infinity,
                                      height: 54,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              _accent,
                                              _accent.withOpacity(0.75),
                                            ],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                          borderRadius:
                                          BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                              _accent.withOpacity(0.35),
                                              blurRadius: 16,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed:
                                          _isLoading ? null : _createUser,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                            Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: _isLoading
                                              ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child:
                                            CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                              : Row(
                                            mainAxisAlignment:
                                            MainAxisAlignment
                                                .center,
                                            children: [
                                              Icon(
                                                _isAdmin
                                                    ? Icons
                                                    .admin_panel_settings_rounded
                                                    : _isStaff
                                                    ? Icons
                                                    .school_rounded
                                                    : Icons
                                                    .person_add_rounded,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                _isAdmin
                                                    ? 'Create Admin Account'
                                                    : 'Create ${_isStaff ? 'Staff' : 'Student'} Account',
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight:
                                                  FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Field label ───────────────────────────────────────────────────────────
  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _ink,
        ),
      ),
    );
  }

  // ── Generic input field ───────────────────────────────────────────────────
  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
    List<TextInputFormatter>? inputFormatters,
    bool isLoading = false,
    String? errorMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _ink,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 13, color: _inkMuted),
              prefixIcon: Icon(icon, color: _inkMuted, size: 20),
              suffixIcon: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFEF9F27),
                        ),
                      ),
                    )
                  : suffix != null
                      ? Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: suffix,
                        )
                      : null,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: errorMessage != null
                    ? const BorderSide(color: Color(0xFFD85A30), width: 1.5)
                    : BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              errorMessage,
              style: const TextStyle(
                color: Color(0xFFD85A30),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Password field ────────────────────────────────────────────────────────
  Widget _passwordField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _ink,
        ),
        decoration: InputDecoration(
          hintText: "Min. 8 characters",
          hintStyle: const TextStyle(fontSize: 13, color: _inkMuted),
          prefixIcon: const Icon(
            Icons.lock_outline_rounded,
            color: _inkMuted,
            size: 20,
          ),
          suffixIcon: IconButton(
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: _inkMuted,
              size: 20,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}