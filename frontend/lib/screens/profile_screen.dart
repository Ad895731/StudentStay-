import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'admin_verification_screen.dart';
import 'saved_stays_screen.dart';

class ProfileScreen extends StatefulWidget {
  final AuthService authService;

  const ProfileScreen({
    super.key,
    required this.authService,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Login Form
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginObscure = true;

  // Register Form
  final _registerFormKey = GlobalKey<FormState>();
  final _regNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  String _selectedRole = 'student';
  bool _regObscure = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _regNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    final success = await widget.authService.login(
      email: _loginEmailController.text.trim(),
      password: _loginPasswordController.text,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome back, ${widget.authService.currentUser?.name}!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;

    final success = await widget.authService.register(
      name: _regNameController.text.trim(),
      email: _regEmailController.text.trim(),
      password: _regPasswordController.text,
      role: _selectedRole,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account created! Welcome, ${widget.authService.currentUser?.name}!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of StudentStay?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirm_logout_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.authService.logout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed out successfully.'),
          ),
        );
      }
    }
  }

  Widget _buildAuthenticatedView() {
    final user = widget.authService.currentUser!;
    final isOwner = user.isOwner;
    final isAdmin = user.isAdmin;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // User Profile Card
          Card(
            key: const Key('user_profile_card'),
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: isOwner ? Colors.deepOrange.shade100 : Colors.blue.shade100,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isOwner ? Colors.deepOrange.shade800 : Colors.blue.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  // Role Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: isOwner ? const Color(0xFFFFF3E0) : const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: 
                        isAdmin ? Colors.purple.shade300 
                        :isOwner ? Colors.orange.shade300 
                        : Colors.blue.shade300,
                      ),
                    ),
                    child: Text(
                      isAdmin ? 'ADMINISTRATOR':
                      isOwner ? 'PROPERTY OWNER' : 'STUDENT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isOwner ? Colors.deepOrange.shade900 : Colors.blue.shade900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Saved Stays Action Card
          Card(
            key: const Key('profile_saved_stays_card'),
            elevation: 2,
            color: Colors.red.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.red.shade200),
            ),
            child: ListTile(
              leading: const Icon(Icons.favorite, color: Colors.red, size: 28),
              title: const Text(
                'My Saved Stays',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('View your shortlisted student accommodations'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SavedStaysScreen(
                      apiService: ApiService(),
                      authService: widget.authService,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Agar logged-in user admin hai toh verification portal ka shortcut card dikhaya hai
          if (isAdmin) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              color: Colors.purple.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.purple.shade200),
              ),
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Colors.purple, size: 32),
                title: const Text(
                  'Admin Verification Portal',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Review and verify pending property listings'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.purple),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AdminVerificationScreen(
                        token: widget.authService.token!,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          Card(
            elevation: 1,
            color: Colors.grey.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    isOwner ? Icons.real_estate_agent : Icons.school,
                    size: 32,
                    color: isOwner ? Colors.orange.shade700 : Colors.blue.shade700,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      isOwner
                          ? 'You can list accommodations, manage photos, and review student inquiries via the Owner Portal.'
                          : 'You can discover verified student accommodations, compare rents, view interactive maps, and get directions.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Logout Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              key: const Key('logout_button'),
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthForms() {
    final isLoading = widget.authService.isLoading;
    final error = widget.authService.authError;

    return Column(
      children: [
        Material(
          color: Colors.blue.shade50,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.blue.shade800,
            unselectedLabelColor: Colors.grey.shade700,
            indicatorColor: Colors.blue.shade800,
            tabs: const [
              Tab(key: Key('tab_sign_in'), text: 'Sign In'),
              Tab(key: Key('tab_create_account'), text: 'Create Account'),
            ],
          ),
        ),

        if (error != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                  onPressed: widget.authService.clearError,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // 1. Sign In Form
              SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _loginFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Welcome Back',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sign in to your StudentStay account',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        key: const Key('login_email_input'),
                        controller: _loginEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address *',
                          hintText: 'e.g. aditya@example.com',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter your email';
                          if (!val.contains('@')) return 'Please enter a valid email address';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        key: const Key('login_password_input'),
                        controller: _loginPasswordController,
                        obscureText: _loginObscure,
                        decoration: InputDecoration(
                          labelText: 'Password *',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_loginObscure ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _loginObscure = !_loginObscure),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Please enter your password';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          key: const Key('submit_login_button'),
                          onPressed: isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Register Form
              SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _registerFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Join StudentStay',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create your account as a student or property owner',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      ),
                      const SizedBox(height: 18),

                      TextFormField(
                        key: const Key('register_name_input'),
                        controller: _regNameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name *',
                          hintText: 'e.g. Aditya Sharma',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter your full name';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        key: const Key('register_email_input'),
                        controller: _regEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address *',
                          hintText: 'e.g. aditya@example.com',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter your email';
                          if (!val.contains('@')) return 'Please enter a valid email address';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        key: const Key('register_password_input'),
                        controller: _regPasswordController,
                        obscureText: _regObscure,
                        decoration: InputDecoration(
                          labelText: 'Password (min. 6 characters) *',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_regObscure ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _regObscure = !_regObscure),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Role Selector
                      const Text('I want to use StudentStay as: *', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              key: const Key('role_student_chip'),
                              label: const Text('🎓 Student / Seeker'),
                              selected: _selectedRole == 'student',
                              onSelected: (sel) {
                                if (sel) setState(() => _selectedRole = 'student');
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              key: const Key('role_owner_chip'),
                              label: const Text('🏠 Property Owner'),
                              selected: _selectedRole == 'owner',
                              onSelected: (sel) {
                                if (sel) setState(() => _selectedRole = 'owner');
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          key: const Key('submit_register_button'),
                          onPressed: isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.authService,
      builder: (context, _) {
        final isAuthenticated = widget.authService.isAuthenticated;

        return Scaffold(
          appBar: AppBar(
            title: Text(isAuthenticated ? 'My Profile' : 'Account & Authentication'),
          ),
          body: isAuthenticated ? _buildAuthenticatedView() : _buildAuthForms(),
        );
      },
    );
  }
}
