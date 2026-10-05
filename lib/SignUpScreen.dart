import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  bool hidePassword = true;
  bool agreeTerms = false;
  bool isLoading = false;
  String? _pickedImageBase64;
  Uint8List? _pickedImageBytes;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Color(0xFF060810),
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);
      setState(() {
        _pickedImageBytes = bytes;
        _pickedImageBase64 = base64String;
      });
    } catch (e) {
      showMessage('Could not pick image: $e');
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101726),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Add Profile Photo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5A623).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFFF5A623), size: 22),
                ),
                title: const Text('Take Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickProfileImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5A623).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFFF5A623), size: 22),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickProfileImage(ImageSource.gallery);
                },
              ),
              if (_pickedImageBytes != null)
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                  ),
                  title: const Text('Remove Photo', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    setState(() {
                      _pickedImageBytes = null;
                      _pickedImageBase64 = null;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> createAccount() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      showMessage('Please complete all fields.');
      return;
    }
    if (!agreeTerms) {
      showMessage('Please accept Terms and Privacy Policy.');
      return;
    }

    setState(() => isLoading = true);

    try {
      // Creates the account in Firebase Authentication.
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // Stores your extra user data in Firestore.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'name': name,
        'email': email,
        'phone': phone,
        'role': 'customer',
        if (_pickedImageBase64 != null) 'profileImage': _pickedImageBase64,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      showMessage('Account created successfully.');
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      String message = 'Could not create the account.';
      if (e.code == 'weak-password') message = 'Password must contain at least 6 characters.';
      if (e.code == 'email-already-in-use') message = 'This email is already registered.';
      if (e.code == 'invalid-email') message = 'Enter a valid email address.';
      showMessage(message);
    } on FirebaseException catch (_) {
      showMessage('Account was created, but profile data could not be saved.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget inputField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Color(0xFFB0B8CB), fontSize: 13)),
      const SizedBox(height: 8),
      Container(
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xB30A0E1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(.10)),
        ),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          autocorrect: false,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF5A6178)),
            prefixIcon: Icon(icon, color: const Color(0xFFF5A623), size: 20),
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(vertical: 17),
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF060810),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B2540), Color(0xFF0A0F1E), Color(0xFF060810)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final sidePadding = constraints.maxWidth < 380 ? 16.0 : 24.0;
            final formWidth = (constraints.maxWidth - sidePadding * 2)
                .clamp(0.0, 440.0)
                .toDouble();

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: sidePadding, vertical: 20),
              child: Center(
                child: SizedBox(
                  width: formWidth,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: isLoading ? null : () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Back to login'),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFFB0B8CB)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(child: Column(children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFFC15C), Color(0xFFF5A623)]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.confirmation_number_rounded, color: Color(0xFF1A1000), size: 28),
                      ),
                      const SizedBox(height: 14),
                      const Text('Create your account', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      const Text('Join in seconds, wait from anywhere', style: TextStyle(color: Color(0xFF8B93A7), fontSize: 13)),
                    ])),
                    const SizedBox(height: 26),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xCC161F35),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withOpacity(.10)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Center(
                          child: GestureDetector(
                            onTap: _showImagePickerSheet,
                            child: Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFF5A623).withOpacity(0.8),
                                      width: 2,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 38,
                                    backgroundColor: const Color(0xFF232D48),
                                    backgroundImage: _pickedImageBytes != null
                                        ? MemoryImage(_pickedImageBytes!)
                                        : null,
                                    child: _pickedImageBytes == null
                                        ? const Icon(
                                            Icons.person_add_alt_1_rounded,
                                            color: Color(0xFFFFC880),
                                            size: 32,
                                          )
                                        : null,
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5A623),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFF060810), width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Color(0xFF17100A),
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            _pickedImageBytes != null ? 'Tap to change photo' : 'Add Profile Photo (Optional)',
                            style: const TextStyle(
                              color: Color(0xFFB0B8CB),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        inputField(label: 'Full name', hint: 'Aditi Sharma', icon: Icons.person_outline, controller: nameController, keyboardType: TextInputType.name),
                        const SizedBox(height: 16),
                        inputField(label: 'Email address', hint: 'you@example.com', icon: Icons.email_outlined, controller: emailController, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 16),
                        inputField(label: 'Phone number', hint: '+91 98765 43210', icon: Icons.phone_outlined, controller: phoneController, keyboardType: TextInputType.phone),
                        const SizedBox(height: 16),
                        inputField(
                          label: 'Password', hint: 'At least 6 characters', icon: Icons.lock_outline,
                          controller: passwordController, obscureText: hidePassword,
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => hidePassword = !hidePassword),
                            icon: Icon(hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: const Color(0xFF8B93A7)),
                          ),
                        ),
                        const SizedBox(height: 18),
                        InkWell(
                          onTap: isLoading ? null : () => setState(() => agreeTerms = !agreeTerms),
                          child: Row(children: [
                            Checkbox(value: agreeTerms, activeColor: const Color(0xFFF5A623), onChanged: isLoading ? null : (value) => setState(() => agreeTerms = value ?? false)),
                            const Expanded(child: Text('I agree to the Terms and Privacy Policy', style: TextStyle(color: Color(0xFFB0B8CB), fontSize: 13))),
                          ]),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: isLoading ? null : createAccount,
                            icon: isLoading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1000)))
                                : const Icon(Icons.arrow_forward_rounded),
                            label: Text(isLoading ? 'Creating account...' : 'Create account'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: const Color(0xFF1A1000),
                              backgroundColor: const Color(0xFFF5A623),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text('Already have an account? ', style: TextStyle(color: Color(0xFF8B93A7), fontSize: 14)),
                      TextButton(onPressed: () => Navigator.maybePop(context), child: const Text('Log in', style: TextStyle(color: Color(0xFFF5A623), fontWeight: FontWeight.w600))),
                    ]),
                  ]),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
