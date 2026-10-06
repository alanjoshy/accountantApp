import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/google_sign_in_button.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _continueWithEmail() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name and email.'),
        ),
      );
      return;
    }

    // Backend authentication will be added later.
  }

  void _continueWithGoogle() {
    // Google authentication will be added later.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 420,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),

                  Text(
                    'Accountant',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.title,
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Sign in or create your account to continue.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle,
                  ),

                  const SizedBox(height: 40),

                  AuthTextField(
                    controller: _nameController,
                    label: 'Name',
                    hintText: 'Enter your name',
                    keyboardType: TextInputType.name,
                  ),

                  const SizedBox(height: 20),

                  AuthTextField(
                    controller: _emailController,
                    label: 'Email',
                    hintText: 'Enter your email',
                    keyboardType: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _continueWithEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: AppTextStyles.button,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      const Expanded(
                        child: Divider(
                          color: AppColors.divider,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        child: Text(
                          'OR',
                          style: AppTextStyles.subtitle.copyWith(
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Divider(
                          color: AppColors.divider,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  GoogleSignInButton(
                    onPressed: _continueWithGoogle,
                  ),

                  const SizedBox(height: 32),

                  Text(
                    'By continuing, you agree to our Terms and Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitle.copyWith(
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}