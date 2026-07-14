import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final ApiService _api = ApiService();
  String _role = 'student';
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _users = [];
  bool _showInactive = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await _api.getUsersExt(role: _role, includeInactive: _showInactive);
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    return _users.where((user) {
      final name = (user['name'] as String?)?.toLowerCase() ?? '';
      final email = (user['email'] as String?)?.toLowerCase() ?? '';
      final studentId = (user['studentId'] as String?)?.toLowerCase() ?? '';
      final department = (user['department'] as String?)?.toLowerCase() ?? '';
      return name.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          studentId.contains(_searchQuery) ||
          department.contains(_searchQuery);
    }).toList();
  }

  String _generateEmail(String role, String? studentId, String? name) {
    if (role == 'student') {
      return '${studentId ?? ''}@std.edu.lb';
    } else {
      final nameStr = (name ?? '').toLowerCase().replaceAll(' ', '.');
      return '$nameStr@dc.edu.lb';
    }
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    final originalName = user['name'] as String? ?? '';
    final originalPhone = user['phoneNumber'] as String? ?? '';
    final deptCtrl = TextEditingController(text: user['department'] as String?);
    final studentIdCtrl = TextEditingController(text: user['studentId'] as String?);
    String selectedRole = user['role'] as String? ?? 'student';
    
    String currentGeneratedEmail = _generateEmail(
      selectedRole,
      studentIdCtrl.text.trim(),
      originalName,
    );

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          void updateEmailPreview() {
            setModalState(() {
              currentGeneratedEmail = _generateEmail(
                selectedRole,
                studentIdCtrl.text.trim(),
                originalName,
              );
            });
          }
          
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Edit User', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  // Name - read only (blocked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 20, color: Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Name ',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                originalName,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Role - editable
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    items: const [
                      DropdownMenuItem(value: 'student', child: Text('Student')),
                      DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                    decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() {
                          selectedRole = value;
                        });
                        updateEmailPreview();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  // Student ID - editable (only for students)
                  if (selectedRole == 'student') ...[
                    TextField(
                      controller: studentIdCtrl,
                      decoration: const InputDecoration(labelText: 'Student ID', border: OutlineInputBorder()),
                      onChanged: (_) => updateEmailPreview(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Department - editable
                  TextField(
                    controller: deptCtrl,
                    decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  // Phone - read only (blocked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 20, color: Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Phone',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                originalPhone.isEmpty ? 'Not provided' : originalPhone,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Email - read only, auto-generated
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.email_outlined, size: 20, color: Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Email (auto-generated)',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currentGeneratedEmail,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context, true);
                          try {
                            final generatedEmail = _generateEmail(
                              selectedRole,
                              selectedRole == 'student' ? studentIdCtrl.text.trim() : null,
                              originalName,
                            );
                            
                            await _api.updateUser(
                              userId: user['userId'] as String,
                              name: originalName,
                              email: generatedEmail,
                              department: deptCtrl.text.trim(),
                              phoneNumber: originalPhone,
                              role: selectedRole,
                              studentId: selectedRole == 'student' ? studentIdCtrl.text.trim() : null,
                            );
                            await _loadUsers();
                            if (!mounted) return;
                            _showSnack('User updated');
                          } catch (e) {
                            if (!mounted) return;
                            _showSnack('Update failed: $e', isError: true);
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ),
                  ])
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result == true) {}
  }

  Future<void> _deactivateUser(Map<String, dynamic> user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deactivate User'),
        content: Text('Are you sure you want to deactivate ${user['name']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Deactivate')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _api.deleteUser(user['userId'] as String);
      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User deactivated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deactivate failed: $e')));
    }
  }

  Future<void> _activateUser(Map<String, dynamic> user) async {
    try {
      await _api.activateUser(user['userId'] as String);
      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User activated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Activate failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Design tokens
    const Color brand = Color(0xFF1D9E75);
    const Color surface = Color(0xFFF8F7F4);
    const Color ink = Color(0xFF1A1A2E);
    const Color inkMuted = Color(0xFF888780);

    return Scaffold(
      backgroundColor: surface,
      body: Stack(
        children: [
          // Gradient header
          Container(
            height: 220,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF5DCAA5), Color(0xFF9FE1CB), Color(0xFFF0997B), Color(0xFFD85A30)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.35, 0.70, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Manage Users', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                          SizedBox(height: 2),
                          Text('View, edit & activate/deactivate accounts', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                      const Spacer(),
                      if (_loading) const CircularProgressIndicator(color: Colors.white),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // White sheet
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(top: 12, bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD3D1C7),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Role filter chips
                                Row(
                                  children: [
                                    Expanded(child: _roleChip('Students', 'student', ink, inkMuted)),
                                    const SizedBox(width: 8),
                                    Expanded(child: _roleChip('Doctors', 'doctor', ink, inkMuted)),
                                    const SizedBox(width: 8),
                                    Expanded(child: _roleChip('Admins', 'admin', ink, inkMuted)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        onChanged: (value) {
                                          setState(() {
                                            _searchQuery = value.trim().toLowerCase();
                                          });
                                        },
                                        decoration: InputDecoration(
                                          hintText: 'Search by name, ID, department or email',
                                          prefixIcon: const Icon(Icons.search),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text('Show inactive', style: TextStyle(fontSize: 13)),
                                            Switch(
                                              value: _showInactive,
                                              onChanged: (v) {
                                                setState(() {
                                                  _showInactive = v;
                                                });
                                                _loadUsers();
                                              },
                                            ),
                                          ],
                                        ),
                                        if (_role != 'admin')
                                          Text('${_users.length}', style: const TextStyle(fontSize: 13, color: Color(0xFF888780))),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: _loading
                                      ? const Center(child: CircularProgressIndicator())
                                      : _error != null
                                          ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFFD85A30))))
                                          : _filteredUsers.isEmpty
                                              ? const Center(child: Padding(padding: EdgeInsets.only(top: 40), child: Text('No users found')))
                                              : ListView.separated(
                                                  physics: const BouncingScrollPhysics(),
                                                  padding: const EdgeInsets.only(bottom: 16),
                                                  itemCount: _filteredUsers.length,
                                                  itemBuilder: (context, index) => _userCard(_filteredUsers[index], brand),
                                                  separatorBuilder: (context, index) => const SizedBox(height: 10),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleChip(String label, String role, Color ink, Color inkMuted) {
    final selected = _role == role;
    return GestureDetector(
      onTap: () {
        setState(() => _role = role);
        _loadUsers();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1D9E75) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(selected ? 0.08 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : ink,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }


  Widget _userCard(Map<String, dynamic> user, Color brand) {
    final active = user['isActive'] == null || user['isActive'] == true;
    final initials = (user['name'] as String?)
        ?.split(' ')
        .map((s) => s.isNotEmpty ? s[0] : '')
        .take(2)
        .join() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: brand.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: brand,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1A1A2E),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${user['studentId'] ?? user['userId'] ?? ''}  •  ${user['department'] ?? ''}',
                  style: const TextStyle(
                    color: Color(0xFF888780),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFF1D9E75).withOpacity(0.10)
                            : const Color(0xFF888780).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        active ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: active
                              ? const Color(0xFF1D9E75)
                              : const Color(0xFF888780),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              GestureDetector(
                onTap: () => _editUser(user),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: brand.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.edit_rounded, color: brand, size: 16),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => active ? _deactivateUser(user) : _activateUser(user),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFFD85A30).withOpacity(0.10)
                        : brand.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    active ? 'Deactivate' : 'Activate',
                    style: TextStyle(
                      color: active ? const Color(0xFFD85A30) : brand,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? const Color(0xFFD85A30) : const Color(0xFF1D9E75),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }
}