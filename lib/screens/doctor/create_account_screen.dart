import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen>
    with SingleTickerProviderStateMixin {
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _isLoadingId = false;
  String? _errorMessage;
  final ApiService _apiService = ApiService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  final List<Map<String, String>> _departments = [
    {'value': 'software', 'label': 'Software Engineering'},
    {'value': 'Multimedia', 'label': 'Multimedia Engineering'},
    {'value': 'System', 'label': 'System Engineering'},
    {'value': 'Telecom', 'label': 'Telecom Engineering'},
  ];
  String? _selectedDept;
  String _selectedRole = "doctor";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
    
    _autoFillDoctorId();
  }

  Future<void> _autoFillDoctorId() async {
    setState(() => _isLoadingId = true);

    try {
      final doctors = await _apiService.getUsersExt(
        role: 'doctor',
        includeInactive: true,
      );

      const int base = 202610000;
      int maxId = base - 1;

      for (final d in doctors) {
        final raw = d['userId'];
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

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _idController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    final name = _nameController.text.trim();
    final id = _idController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty || id.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = "Name, ID, and password are required");
      return;
    }

    if (password != confirmPassword) {
      setState(() => _errorMessage = "Passwords do not match");
      return;
    }

    if (password.length < 8) {
      setState(() => _errorMessage = "Password must be at least 8 characters");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _selectedRole == 'doctor'
          ? '$id@dc.edu.lb'
          : '$id@std.edu.lb';

      await _apiService.createUser(
        name: name,
        email: email,
        password: password,
        role: _selectedRole,
        studentId: _selectedRole == 'student' ? id : null,
        department: _selectedDept ?? 'General',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Account created. You can now sign in."),
          backgroundColor: Color(0xFF1D9E75),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      setState(
        () => _errorMessage = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Warm gradient background ──
          Container(
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

          // ── Decorative blobs ──
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),

          // ── Main content ──
          SafeArea(
            child: Column(
              children: [
                // ── Top bar with back button ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
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
                      Text(
                        "Step 1 of 1",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: FadeTransition(
                      opacity: _fadeIn,
                      child: SlideTransition(
                        position: _slideUp,
                        child: Column(
                          children: [
                            const SizedBox(height: 12),

                            // ── Logo badge ──
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.12),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.person_add_rounded,
                                  size: 30,
                                  color: Color(0xFF1D9E75),
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            const Text(
                              "Create Your Account",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.20),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                "Faculty of Engineering",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // ── White Card ──
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.10),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                24,
                                24,
                                24,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ── Full Name ──
                                  _buildLabel("Full Name"),
                                  const SizedBox(height: 8),
                                  _buildTextField(
                                    controller: _nameController,
                                    hintText: "Dr. Ahmed Hassan",
                                    prefixIcon: Icons.badge_outlined,
                                  ),

                                  const SizedBox(height: 16),

                                  // ── ID ──
                                  _buildLabel("ID Number"),
                                  const SizedBox(height: 8),
                                  _buildTextField(
                                    controller: _idController,
                                    hintText: "202610001",
                                    prefixIcon: Icons.numbers_rounded,
                                    keyboardType: TextInputType.number,
                                    isLoading: _isLoadingId,
                                  ),

                                  const SizedBox(height: 16),

                                  // ── Department Dropdown ──
                                  _buildLabel("Department"),
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1EFE8),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedDept,
                                        isExpanded: true,
                                        hint: const Text(
                                          "Select your department",
                                          style: TextStyle(
                                            color: Color(0xFFB4B2A9),
                                            fontSize: 14,
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: Color(0xFF888780),
                                        ),
                                        items: _departments.map((dept) {
                                          return DropdownMenuItem<String>(
                                            value: dept['value'],
                                            child: Text(
                                              dept['label']!,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF2C2C2A),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (val) =>
                                            setState(() => _selectedDept = val),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // ── Role Dropdown ──
                                  _buildLabel("Role"),
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1EFE8),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedRole,
                                        isExpanded: true,
                                        icon: const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: Color(0xFF888780),
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: "doctor",
                                            child: Text("Doctor"),
                                          ),
                                          DropdownMenuItem(
                                            value: "student",
                                            child: Text("Student"),
                                          ),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() => _selectedRole = val);
                                          }
                                        },
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  _buildLabel("Password"),
                                  const SizedBox(height: 8),
                                  _buildPasswordField(
                                    controller: _passwordController,
                                    hintText: "Create a strong password",
                                    obscure: _obscurePassword,
                                    onToggle: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // ── Confirm Password ──
                                  _buildLabel("Confirm Password"),
                                  const SizedBox(height: 8),
                                  _buildPasswordField(
                                    controller: _confirmPasswordController,
                                    hintText: "Re-enter your password",
                                    obscure: _obscureConfirm,
                                    onToggle: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm,
                                    ),
                                  ),

                                  if (_errorMessage != null) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 24),

                                  // Info hint
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1D9E75).withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.info_outline, size: 14, color: Color(0xFF1D9E75)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _selectedRole == 'doctor'
                                                ? 'Email will be: ID@dc.edu.lb'
                                                : 'Email will be: ID@std.edu.lb',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF1D9E75)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // ── Create Account Button ──
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF5DCAA5),
                                            Color(0xFF1D9E75),
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF1D9E75,
                                            ).withOpacity(0.35),
                                            blurRadius: 16,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: _isLoading
                                            ? null
                                            : _createAccount,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.check_circle_outline,
                                                    size: 18,
                                                    color: Colors.white,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    "Create Account",
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors.white,
                                                      letterSpacing: 0.4,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // ── Back to login ──
                                  Center(
                                    child: GestureDetector(
                                      onTap: () => Navigator.pop(context),
                                      child: RichText(
                                        text: const TextSpan(
                                          text: "Already have an account? ",
                                          style: TextStyle(
                                            color: Color(0xFF888780),
                                            fontSize: 13,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: "Sign In",
                                              style: TextStyle(
                                                color: Color(0xFF1D9E75),
                                                fontWeight: FontWeight.w700,
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

                            const SizedBox(height: 28),
                            Text(
                              "For IT support, contact helpdesk@university.edu",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.65),
                              ),
                            ),
                            const SizedBox(height: 32),
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF444441),
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1EFE8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, color: Color(0xFF2C2C2A)),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFFB4B2A9), fontSize: 14),
          prefixIcon: Icon(prefixIcon, size: 20, color: const Color(0xFF888780)),
          suffixIcon: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1D9E75)),
                  ),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1D9E75), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1EFE8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(fontSize: 14, color: Color(0xFF2C2C2A)),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFFB4B2A9), fontSize: 14),
          prefixIcon: const Icon(
            Icons.lock_outline_rounded,
            size: 20,
            color: Color(0xFF888780),
          ),
          suffixIcon: GestureDetector(
            onTap: onToggle,
            child: Icon(
              obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 20,
              color: const Color(0xFF888780),
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1D9E75), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
        ),
      ),
    );
  }
}