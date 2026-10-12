import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'AdminDataHelper.dart';


class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Mode: 0 = Sign In, 1 = Create Account
  int _authMode = 0;

  // Selected Roles (0 = Business Admin, 1 = Staff Member)
  int _signInRole = 0;
  int _createRole = 0;

  // Password visibility
  bool _obscureSignInPassword = true;
  bool _obscureStaffPassword = true;
  bool _obscureStaffConfirm = true;

  // Form Dropdown Values
  String? _selectedService;

  // Controllers
  final _signInEmailController = TextEditingController();
  final _signInPasswordController = TextEditingController();

  final _staffNameController = TextEditingController();
  final _staffEmailController = TextEditingController();
  final _staffPhoneController = TextEditingController();
  final _staffBizIdController = TextEditingController();
  final _staffPasswordController = TextEditingController();
  final _staffConfirmPasswordController = TextEditingController();

  // Color Definitions
  static const Color primaryContainer = Color(0xFFF5A623);
  static const Color primaryColor = Color(0xFFFFC880);
  static const Color tertiaryColor = Color(0xFFB8D4FF);
  static const Color onSurface = Color(0xFFDAE2FF);
  static const Color onSurfaceVariant = Color(0xFFD7C3AE);
  static const Color surfaceContainer = Color(0xFF141F39);

  final List<Map<String, String>> _services = const [
    {'value': 'counter1', 'label': 'Counter 1 - General'},
    {'value': 'counter2', 'label': 'Counter 2 - Express'},
    {'value': 'consultation', 'label': 'Consultation Room'},
    {'value': 'checkout', 'label': 'Checkout / Payment'},
  ];
  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> signIn() async {
    try {
      final email = _signInEmailController.text.trim();
      final password = _signInPasswordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        showMessage('Enter ${_signInRole == 0 ? "username and password" : "email and password"}');
        return;
      }

      // Static Admin Login - dynamic database insertion/lookup not required
      if (_signInRole == 0) {
        if ((email.toLowerCase() == 'admin' ||
                email.toLowerCase() == 'admin@admin.com' ||
                email.toLowerCase() == 'admin@queueless.com') &&
            password == 'admin') {
          // Authenticate silent admin session with Firebase to satisfy Firestore rules
          await AdminDataHelper.ensureAdminAuth();

          if (!mounted) return;
          showMessage('Welcome back, Admin!');
          Navigator.pushReplacementNamed(context, '/adminDashboard');
          return;
        } else {
          showMessage('Invalid admin credentials. Use admin / admin');
          return;
        }
      }

      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        showMessage('User role was not found');
        return;
      }

      final role = userDoc.data()?['role'];

      // 0 = Admin selected, 1 = Staff selected
      if (_signInRole == 0 && role != 'admin') {
        await FirebaseAuth.instance.signOut();
        showMessage('This account is not a Business Admin account');
        return;
      }

      if (_signInRole == 1 && role != 'staff') {
        await FirebaseAuth.instance.signOut();
        showMessage('This account is not a Staff account');
        return;
      }

      if (!mounted) return;

      if (role == 'admin') {
        Navigator.pushReplacementNamed(context, '/adminDashboard');
      } else if (role == 'staff') {
        Navigator.pushReplacementNamed(context, '/staffDashboard');
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed. Please try again.';

      if (e.code == 'invalid-credential' ||
          e.code == 'wrong-password' ||
          e.code == 'user-not-found') {
        message = 'Incorrect email or password.';
      } else if (e.code == 'invalid-email') {
        message = 'Enter a valid email address.';
      } else if (e.code == 'network-request-failed') {
        message = 'Check your internet connection.';
      }

      showMessage(message);
    } catch (e) {
      showMessage('Something went wrong. Please try again.');
    }
  }


  Future<void> createStaffAccount() async {
    try {
      if (_staffPasswordController.text !=
          _staffConfirmPasswordController.text) {
        showMessage('Passwords do not match');
        return;
      }

      if (_staffBizIdController.text.trim().isEmpty) {
        showMessage('Enter Business ID or Invite Code');
        return;
      }

      if (_selectedService == null) {
        showMessage('Select an assigned service');
        return;
      }

      final businessId = _staffBizIdController.text.trim();

      // First create Firebase Authentication account.
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _staffEmailController.text.trim(),
        password: _staffPasswordController.text.trim(),
      );

      // Staff is logged in now, so Firestore Rules allow this read.
      final businessDoc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .get();

      if (!businessDoc.exists) {
        await credential.user?.delete();
        await FirebaseAuth.instance.signOut();

        showMessage('Business ID is not valid');
        return;
      }

      // Save Staff profile in Firestore.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'name': _staffNameController.text.trim(),
        'email': _staffEmailController.text.trim(),
        'phone': _staffPhoneController.text.trim(),
        'role': 'staff',
        'businessId': businessId,
        'assignedService': _selectedService,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      showMessage('Staff account created successfully');

      Navigator.pushReplacementNamed(
        context,
        '/staffDashboard',
      );
    } on FirebaseAuthException catch (e) {
      showMessage(e.message ?? 'Could not create staff account');
    } on FirebaseException catch (e) {
      showMessage(e.message ?? 'Firebase permission error');
    } catch (e) {
      showMessage('Something went wrong. Please try again.');
    }
  }

  Future<void> resetPassword() async {
    if (_signInRole == 0) {
      showMessage('Admin password is static: admin');
      return;
    }

    try {
      final email = _signInEmailController.text.trim();

      if (email.isEmpty) {
        showMessage('Enter your email address first');
        return;
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      showMessage('Password reset email sent');
    } on FirebaseAuthException catch (e) {
      showMessage(e.message ?? 'Could not send reset email');
    }
  }
  @override
  void dispose() {
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _staffNameController.dispose();
    _staffEmailController.dispose();
    _staffPhoneController.dispose();
    _staffBizIdController.dispose();
    _staffPasswordController.dispose();
    _staffConfirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width >= 1024;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient Mesh
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1B2540), Color(0xFF060810)],
              ),
            ),
          ),

          // Blurred Decorative Ambient Glows
          Positioned(
            top: -screenSize.height * 0.2,
            right: -screenSize.width * 0.1,
            child: Container(
              width: screenSize.width * 0.45,
              height: screenSize.width * 0.45,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryContainer.withValues(alpha: 0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            bottom: -screenSize.height * 0.2,
            left: -screenSize.width * 0.1,
            child: Container(
              width: screenSize.width * 0.45,
              height: screenSize.width * 0.45,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tertiaryColor.withValues(alpha: 0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // Main Responsive Content Area
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (isDesktop) ...[
                      Expanded(
                        flex: 45,
                        child: _buildLeftHeroSection(),
                      ),
                      const SizedBox(width: 48),
                    ],
                    Expanded(
                      flex: isDesktop ? 55 : 100,
                      child: Center(
                        child: _buildGlassCard(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftHeroSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryContainer, primaryColor],
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryContainer.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.confirmation_number_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Manage every queue with confidence',
            style: GoogleFonts.inter(
              fontSize: 48,
              height: 1.15,
              letterSpacing: -1.0,
              fontWeight: FontWeight.w700,
              color: onSurface,
            ),
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(
              'Run your counter, serve customers faster, and keep every line moving.',
              style: GoogleFonts.inter(
                fontSize: 16,
                height: 1.5,
                color: onSurfaceVariant.withValues(alpha: 0.9),
              ),
            ),
          ),
          const SizedBox(height: 40),
          _buildFeatureItem(Icons.tune_rounded, primaryColor, 'Live queue control'),
          const SizedBox(height: 20),
          _buildFeatureItem(Icons.notifications_active_rounded, tertiaryColor, 'Real-time customer updates'),
          const SizedBox(height: 20),
          _buildFeatureItem(Icons.insights_rounded, primaryColor, 'Business insights'),
          const SizedBox(height: 56),
          Row(
            children: [
              Icon(Icons.storefront_outlined, size: 16, color: onSurfaceVariant.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
              Text(
                'QueueLess • Smart queue management',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w600,
                  color: onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, Color iconColor, String title) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: surfaceContainer,
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 16),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: screenHeight * 0.85,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF2A3450).withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Glow Border Line
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // Segmented Control (Sign In / Create Account)
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 16),
                child: _buildSegmentedAuthSwitch(),
              ),

              // Scrollable Dynamic Content Pane
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.0, 0.05),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _authMode == 0
                        ? _buildSignInView()
                        : _buildCreateAccountView(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedAuthSwitch() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final halfWidth = (constraints.maxWidth - 8) / 2;
          return Stack(
            children: [
              // Animated Background Indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.fastOutSlowIn,
                left: _authMode == 0 ? 0 : halfWidth,
                top: 0,
                bottom: 0,
                width: halfWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: primaryContainer.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(
                      color: primaryContainer.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9999),
                      onTap: () => setState(() => _authMode = 0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Sign In',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _authMode == 0 ? onSurface : onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9999),
                      onTap: () => setState(() => _authMode = 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Create Account',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _authMode == 1 ? onSurface : onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSignInView() {
    return Column(
      key: const ValueKey('signin_view'),
      children: [
        // Header
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryContainer.withValues(alpha: 0.1),
            border: Border.all(color: primaryContainer.withValues(alpha: 0.2)),
          ),
          child: const Icon(Icons.login_rounded, color: primaryContainer, size: 20),
        ),
        const SizedBox(height: 14),
        Text(
          'Welcome back',
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Sign in to access your workspace',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 24),

        // Role Selector
        Row(
          children: [
            Expanded(
              child: _buildRoleButton(
                title: 'Business Admin',
                icon: Icons.admin_panel_settings_outlined,
                iconColor: primaryContainer,
                isSelected: _signInRole == 0,
                onTap: () => setState(() => _signInRole = 0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildRoleButton(
                title: 'Staff Member',
                icon: Icons.badge_outlined,
                iconColor: tertiaryColor,
                isSelected: _signInRole == 1,
                onTap: () => setState(() => _signInRole = 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_signInRole == 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: primaryContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: primaryContainer.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Static Admin Login: admin / admin',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: primaryColor,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _signInEmailController.text = 'admin';
                      _signInPasswordController.text = 'admin';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryContainer.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Auto Fill',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Text Fields
        _buildInputField(
          controller: _signInEmailController,
          hintText: _signInRole == 0 ? 'Username (e.g. admin)' : 'Email address',
          prefixIcon: _signInRole == 0 ? Icons.person_outline_rounded : Icons.mail_outline_rounded,
          keyboardType: _signInRole == 0 ? TextInputType.text : TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _buildInputField(
          controller: _signInPasswordController,
          hintText: _signInRole == 0 ? 'Password (e.g. admin)' : 'Password',
          prefixIcon: Icons.lock_outline_rounded,
          isPassword: true,
          obscureText: _obscureSignInPassword,
          onToggleVisibility: () {
            setState(() => _obscureSignInPassword = !_obscureSignInPassword);
          },
        ),
        const SizedBox(height: 20),

        // Submit Button
        _buildSubmitButton(
          text: 'Sign in',
          onTap: signIn,
        ),
        const SizedBox(height: 16),

        // Forgot password
        TextButton(
    onPressed: resetPassword,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Forgot password?',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Footer Note
        _buildFooterNote(),
      ],
    );
  }

  Widget _buildCreateAccountView() {
    return Column(
      key: const ValueKey('create_account_view'),
      children: [
        // Header
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryContainer.withValues(alpha: 0.1),
            border: Border.all(color: primaryContainer.withValues(alpha: 0.2)),
          ),
          child: const Icon(Icons.person_add_outlined, color: primaryContainer, size: 20),
        ),
        const SizedBox(height: 12),
        Text(
          'Join QueueLess',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Select your role to get started',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 20),

        // Registration Role Selector
        Row(
          children: [
            Expanded(
              child: _buildRoleButton(
                title: 'Business Admin',
                icon: Icons.admin_panel_settings_outlined,
                iconColor: primaryContainer,
                isSelected: _createRole == 0,
                onTap: () => setState(() => _createRole = 0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildRoleButton(
                title: 'Staff Member',
                icon: Icons.badge_outlined,
                iconColor: tertiaryColor,
                isSelected: _createRole == 1,
                onTap: () => setState(() => _createRole = 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Conditional Form Elements
        if (_createRole == 0)
          _buildAdminStaticNotice()
        else ...[
          ..._buildStaffFormFields(),
          const SizedBox(height: 24),
          _buildSubmitButton(
            text: 'Create staff account',
            onTap: createStaffAccount,
          ),
        ],
      ],
    );
  }

  Widget _buildAdminStaticNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryContainer.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryContainer.withValues(alpha: 0.15),
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: primaryContainer,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Dynamic Insert Not Required',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Business Admin uses static credentials. No registration or database insertion is required. Sign in directly with admin credentials.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'Username',
                      style: GoogleFonts.inter(fontSize: 11, color: onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'admin',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.1)),
                Column(
                  children: [
                    Text(
                      'Password',
                      style: GoogleFonts.inter(fontSize: 11, color: onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'admin',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildSubmitButton(
            text: 'Sign In as Admin',
            onTap: () {
              setState(() {
                _authMode = 0;
                _signInRole = 0;
                _signInEmailController.text = 'admin';
                _signInPasswordController.text = 'admin';
              });
            },
          ),
        ],
      ),
    );
  }



  List<Widget> _buildStaffFormFields() {
    return [
      _buildInputField(
        controller: _staffNameController,
        hintText: 'Full name',
        prefixIcon: Icons.person_outline_rounded,
      ),
      const SizedBox(height: 14),
      _buildInputField(
        controller: _staffEmailController,
        hintText: 'Email address',
        prefixIcon: Icons.mail_outline_rounded,
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 14),
      _buildInputField(
        controller: _staffPhoneController,
        hintText: 'Phone number',
        prefixIcon: Icons.phone_outlined,
        keyboardType: TextInputType.phone,
      ),
      const SizedBox(height: 14),
      _buildInputField(
        controller: _staffBizIdController,
        hintText: 'Business ID or Invite Code',
        prefixIcon: Icons.corporate_fare_outlined,
      ),
      const SizedBox(height: 14),
      _buildDropdown(
        hint: 'Select assigned service',
        value: _selectedService,
        prefixIcon: Icons.design_services_outlined,
        items: _services,
        onChanged: (val) => setState(() => _selectedService = val),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: _buildInputField(
              controller: _staffPasswordController,
              hintText: 'Password',
              prefixIcon: Icons.lock_outline_rounded,
              isPassword: true,
              obscureText: _obscureStaffPassword,
              onToggleVisibility: () {
                setState(() => _obscureStaffPassword = !_obscureStaffPassword);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildInputField(
              controller: _staffConfirmPasswordController,
              hintText: 'Confirm',
              prefixIcon: Icons.lock_outline_rounded,
              isPassword: true,
              obscureText: _obscureStaffConfirm,
              onToggleVisibility: () {
                setState(() => _obscureStaffConfirm = !_obscureStaffConfirm);
              },
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildRoleButton({
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryContainer.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? primaryContainer : Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: primaryContainer.withValues(alpha: 0.1),
              blurRadius: 10,
            ),
          ]
              : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? primaryContainer : iconColor, size: 20),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? onSurface : onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? obscureText : false,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: GoogleFonts.inter(fontSize: 14, color: onSurface),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: onSurfaceVariant.withValues(alpha: 0.45),
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.only(bottom: maxLines > 1 ? 24 : 0),
            child: Icon(prefixIcon, color: onSurfaceVariant.withValues(alpha: 0.7), size: 18),
          ),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 18,
              color: onSurfaceVariant.withValues(alpha: 0.7),
            ),
            onPressed: onToggleVisibility,
          )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: primaryContainer, width: 1),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required IconData prefixIcon,
    required List<Map<String, String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        dropdownColor: const Color(0xFF141F39),
        style: GoogleFonts.inter(fontSize: 14, color: onSurface),
        icon: Icon(Icons.arrow_drop_down, color: onSurfaceVariant.withValues(alpha: 0.7)),
        decoration: InputDecoration(
          prefixIcon: Icon(prefixIcon, color: onSurfaceVariant.withValues(alpha: 0.7), size: 18),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: primaryContainer, width: 1),
          ),
        ),
        hint: Text(
          hint,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: onSurfaceVariant.withValues(alpha: 0.45),
          ),
        ),
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item['value'],
            child: Text(item['label']!),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSubmitButton({
    required String text,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(colors: [primaryContainer, primaryColor]),
        boxShadow: [
          BoxShadow(
            color: primaryContainer.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Center(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF452B00),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterNote() {
    return Container(
      padding: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 14,
            color: onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'ACCESS IS PROVIDED BY YOUR BUSINESS ADMINISTRATOR',
              style: GoogleFonts.inter(
                fontSize: 10,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w600,
                color: onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}