import 'dart:math' as math;
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AppColors {
  static const bgTop = Color(0xFF1B2540);
  static const bgMid = Color(0xFF0A0F1E);
  static const bgBottom = Color(0xFF060810);
  static const cardGlass = Color(0x99161F35);
  static const cardBorder = Color(0x14FFFFFF);
  static const inputBg = Color(0xB30A0E1A);
  static const inputBorder = Color(0x17FFFFFF);
  static const accent = Color(0xFFF5A623);
  static const accentLight = Color(0xFFFFC15C);
  static const success = Color(0xFF3FCF8E);
  static const textPrimary = Color(0xFFFAFAF7);
  static const textSecondary = Color(0xFF8B93A7);
  static const textMuted = Color(0xFF5A6178);
}

class AppGradients {
  static const background = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.bgTop, AppColors.bgMid, AppColors.bgBottom]);
  static const accentButton = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.accentLight, AppColors.accent]);
  static const tokenText = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFD98C), AppColors.accent]);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool hidePassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> handleLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Enter your email and password.');
      return;
    }

    setState(() => isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      if (!mounted) return;
      _showMessage('Login successful.');
      // Add your dashboard route later:
       Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      var message = 'Login failed. Please try again.';
      if (e.code == 'user-not-found') message = 'No account found for this email.';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') message = 'Incorrect email or password.';
      if (e.code == 'invalid-email') message = 'Enter a valid email address.';
      _showMessage(message);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showMessage(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: true,
    body: Container(
      decoration: const BoxDecoration(gradient: AppGradients.background),
      child: Stack(children: [
        const _GlowBackdrop(),
        SafeArea(child: LayoutBuilder(builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth < 380 ? 16.0 : 24.0;
          final contentWidth = (constraints.maxWidth - horizontalPadding * 2).clamp(0.0, 440.0).toDouble();
          final compact = constraints.maxHeight < 700;
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: compact ? 20 : 32),
            child: Center(child: SizedBox(width: contentWidth, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _Logo(compact: compact),
              SizedBox(height: compact ? 22 : 30),
              _TicketCard(
                compact: compact,
                emailController: emailController,
                passwordController: passwordController,
                hidePassword: hidePassword,
                isLoading: isLoading,
                onToggleHidePassword: () => setState(() => hidePassword = !hidePassword),
                onLoginPressed: handleLogin,
              ),
              SizedBox(height: compact ? 16 : 22),
              const _QrBanner(),
              SizedBox(height: compact ? 16 : 22),
              _SignupRow(onCreateAccount: () => Navigator.pushNamed(context, '/signup')),
            ]))),
          );
        })),
      ]),
    ),
  );
}

class _GlowBackdrop extends StatelessWidget { const _GlowBackdrop(); @override Widget build(BuildContext context) => IgnorePointer(child: Stack(children: [
  Positioned(top: -60, right: -60, child: _GlowBlob(color: AppColors.accent.withOpacity(.18), size: 220)),
  Positioned(bottom: -80, left: -40, child: _GlowBlob(color: const Color(0xFF5078FF).withOpacity(.10), size: 240)),
])); }
class _GlowBlob extends StatelessWidget { const _GlowBlob({required this.color, required this.size}); final Color color; final double size; @override Widget build(BuildContext context) => ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60), child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color))); }

class _Logo extends StatelessWidget { const _Logo({required this.compact}); final bool compact; @override Widget build(BuildContext context) { final iconBox = compact ? 50.0 : 58.0; return Column(children: [
  Container(width: iconBox, height: iconBox, decoration: BoxDecoration(gradient: AppGradients.accentButton, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(.35), blurRadius: 20, offset: const Offset(0, 8))]), child: Icon(Icons.confirmation_number_rounded, color: const Color(0xFF1A1000), size: compact ? 26 : 30)),
  SizedBox(height: compact ? 12 : 16), Text('QueueLess', style: TextStyle(color: AppColors.textPrimary, fontSize: compact ? 23 : 26, fontWeight: FontWeight.w600, letterSpacing: -.6)), const SizedBox(height: 5), const Text('Skip the line. Not the turn.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
]); } }

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.compact, required this.emailController, required this.passwordController, required this.hidePassword, required this.isLoading, required this.onToggleHidePassword, required this.onLoginPressed});
  final bool compact, hidePassword, isLoading; final TextEditingController emailController, passwordController; final VoidCallback onToggleHidePassword; final Future<void> Function() onLoginPressed;
  @override Widget build(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(22), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), child: Container(decoration: BoxDecoration(color: AppColors.cardGlass, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.cardBorder, width: .6)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _TokenHeader(compact: compact), const _DashedDivider(), Padding(padding: EdgeInsets.fromLTRB(20, compact ? 18 : 24, 20, 20), child: Column(children: [
      _AppTextField(label: 'Email address', hint: 'you@example.com', icon: Icons.email_outlined, iconColor: AppColors.accent, controller: emailController, keyboardType: TextInputType.emailAddress), const SizedBox(height: 18),
      _AppTextField(label: 'Password', hint: 'Your password', icon: Icons.lock_outline, iconColor: AppColors.textMuted, controller: passwordController, obscureText: hidePassword, trailingIcon: hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, onTrailingIconTap: onToggleHidePassword), const SizedBox(height: 22),
      _GradientButton(label: isLoading ? 'Logging in...' : 'Take my token', isLoading: isLoading, onPressed: onLoginPressed), const _OrDivider(),
      _OutlineButton(label: 'Continue with Google', icon: Icons.g_mobiledata_rounded, onPressed: isLoading ? null : () {}),
    ])),
  ]))));
}

class _TokenHeader extends StatelessWidget { const _TokenHeader({required this.compact}); final bool compact; @override Widget build(BuildContext context) => Padding(padding: EdgeInsets.fromLTRB(20, compact ? 18 : 24, 20, compact ? 15 : 20), child: Column(children: [
  const Text('NOW BOARDING', style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: 2)), const SizedBox(height: 4), ShaderMask(shaderCallback: AppGradients.tokenText.createShader, child: Text('A-014', style: TextStyle(color: Colors.white, fontSize: compact ? 38 : 44, fontWeight: FontWeight.w700, letterSpacing: 1.5, height: 1))), const SizedBox(height: 9), const Row(mainAxisAlignment: MainAxisAlignment.center, children: [_StatusDot(), SizedBox(width: 7), Text('3 people ahead · ~12 min wait', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))]),
])); }
class _StatusDot extends StatelessWidget { const _StatusDot(); @override Widget build(BuildContext context) => Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)); }

class _DashedDivider extends StatelessWidget { const _DashedDivider(); @override Widget build(BuildContext context) => SizedBox(height: 22, child: Stack(alignment: Alignment.center, children: [Positioned.fill(child: CustomPaint(painter: _DashedLinePainter())), const Align(alignment: Alignment.centerLeft, child: _Notch(isLeft: true)), const Align(alignment: Alignment.centerRight, child: _Notch(isLeft: false))])); }
class _DashedLinePainter extends CustomPainter { @override void paint(Canvas canvas, Size size) { final paint = Paint()..color = AppColors.inputBorder.withOpacity(.9)..strokeWidth = 1.4..strokeCap = StrokeCap.round; for (double x = 11; x < size.width - 11; x += 12) { canvas.drawLine(Offset(x, size.height / 2), Offset(math.min(x + 6, size.width - 11), size.height / 2), paint); } } @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false; }
class _Notch extends StatelessWidget { const _Notch({required this.isLeft}); final bool isLeft; @override Widget build(BuildContext context) => Transform.translate(offset: Offset(isLeft ? -11 : 11, 0), child: Container(width: 22, height: 22, decoration: const BoxDecoration(color: AppColors.bgBottom, shape: BoxShape.circle))); }

class _AppTextField extends StatelessWidget { const _AppTextField({required this.label, required this.hint, required this.icon, required this.iconColor, required this.controller, this.keyboardType = TextInputType.text, this.obscureText = false, this.trailingIcon, this.onTrailingIconTap}); final String label, hint; final IconData icon; final Color iconColor; final TextEditingController controller; final TextInputType keyboardType; final bool obscureText; final IconData? trailingIcon; final VoidCallback? onTrailingIconTap; @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, letterSpacing: .2)), const SizedBox(height: 8), Container(constraints: const BoxConstraints(minHeight: 56), decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.inputBorder, width: .7)), child: TextField(controller: controller, keyboardType: keyboardType, obscureText: obscureText, autocorrect: false, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16), decoration: InputDecoration(border: InputBorder.none, hintText: hint, hintStyle: const TextStyle(color: AppColors.textMuted), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), prefixIcon: Icon(icon, size: 20, color: iconColor), suffixIcon: trailingIcon == null ? null : IconButton(icon: Icon(trailingIcon, size: 20, color: AppColors.textMuted), onPressed: onTrailingIconTap))))]); }

class _GradientButton extends StatelessWidget { const _GradientButton({required this.label, required this.isLoading, required this.onPressed}); final String label; final bool isLoading; final Future<void> Function() onPressed; @override Widget build(BuildContext context) => SizedBox(width: double.infinity, height: 54, child: DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.accentButton, borderRadius: BorderRadius.circular(13), boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(.3), blurRadius: 24, offset: const Offset(0, 10))]), child: Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(13), onTap: isLoading ? null : onPressed, child: Center(child: isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1000))) : Text(label, style: const TextStyle(color: Color(0xFF1A1000), fontSize: 16, fontWeight: FontWeight.w700))))))); }
class _OutlineButton extends StatelessWidget { const _OutlineButton({required this.label, required this.icon, required this.onPressed}); final String label; final IconData icon; final VoidCallback? onPressed; @override Widget build(BuildContext context) => SizedBox(width: double.infinity, height: 52, child: OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon, size: 22, color: AppColors.textSecondary), label: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)), style: OutlinedButton.styleFrom(backgroundColor: Colors.white.withOpacity(.03), side: BorderSide(color: Colors.white.withOpacity(.1), width: .7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))))); }
class _OrDivider extends StatelessWidget { const _OrDivider(); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Row(children: [Expanded(child: Container(height: 1, color: Colors.white.withOpacity(.08))), const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: TextStyle(color: AppColors.textMuted, fontSize: 12))), Expanded(child: Container(height: 1, color: Colors.white.withOpacity(.08)))])); }
class _QrBanner extends StatelessWidget { const _QrBanner(); @override Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13), decoration: BoxDecoration(color: AppColors.accent.withOpacity(.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.accent.withOpacity(.15), width: .7)), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.qr_code_rounded, size: 18, color: AppColors.accent), SizedBox(width: 9), Flexible(child: Text('Scan the counter’s QR to join instantly', textAlign: TextAlign.center, style: TextStyle(color: AppColors.accentLight, fontSize: 12.5)))])); }
class _SignupRow extends StatelessWidget { const _SignupRow({required this.onCreateAccount}); final VoidCallback onCreateAccount; @override Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('New here? ', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)), TextButton(onPressed: onCreateAccount, style: TextButton.styleFrom(foregroundColor: AppColors.accent, minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8), tapTargetSize: MaterialTapTargetSize.shrinkWrap), child: const Text('Create account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))) ]); }
