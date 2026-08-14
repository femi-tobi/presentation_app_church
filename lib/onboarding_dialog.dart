import 'package:flutter/material.dart';
import 'dashboard_page.dart'; // For SacredColors, SacredTypography
import 'settings_state.dart';
import 'form_sync_service.dart';

class OnboardingDialog extends StatefulWidget {
  const OnboardingDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const OnboardingDialog(),
    );
  }

  @override
  State<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<OnboardingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ministryController = TextEditingController();
  final _churchController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ministryController.dispose();
    _churchController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    final name = _nameController.text.trim();
    final ministry = _ministryController.text.trim();
    final church = _churchController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    // 1. Save settings locally
    final settings = AppSettings.instance;
    settings.userName = name;
    settings.userMinistry = ministry;
    settings.userChurch = church;
    settings.userEmail = email;
    settings.userPhone = phone;
    settings.isOnboarded = true;
    
    // Save settings immediately
    await settings.saveSettingsImmediately();

    // 2. Prepare payload for Google Form sync
    final Map<String, String> payload = {
      'entry.1731333237': name,      // FULL NAME
      'entry.2122975167': ministry,  // MINISTRY / DEPARTMENT
      'entry.104166914': church,     // NAME OF CHURCH
      'entry.1128775980': email,     // EMAIL ADDRESS
      'entry.1519689275': phone,     // PHONE NUMBER (WHATSAPP)
      'entry.1364902059': '',         // FEEDBACK (empty on onboarding)
    };

    // Queue submission
    await FormSyncService.instance.queueSubmission(payload);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppSettings.instance.isDarkMode;
    final primaryColor = SacredColors.primary;
    final surfaceColor = SacredColors.surfaceContainer;
    final onSurfaceColor = SacredColors.onBackground;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(
                color: primaryColor.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.5 : 0.1),
                  blurRadius: 20.0,
                  spreadRadius: 2.0,
                ),
              ],
            ),
            padding: const EdgeInsets.all(28.0),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Block
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.account_balance_outlined,
                          color: primaryColor,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'Set Up Your Profile',
                        style: SacredTypography.headlineMd(context).copyWith(
                          fontWeight: FontWeight.bold,
                          color: onSurfaceColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Please enter your information to customize your Live-Deck experience.',
                        textAlign: TextAlign.center,
                        style: SacredTypography.bodyMd(context).copyWith(
                          color: onSurfaceColor.withOpacity(0.7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Inputs
                    _buildLabel(context, 'Full Name'),
                    _buildTextField(
                      controller: _nameController,
                      hint: 'Enter your full name',
                      icon: Icons.person_outline,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Full name is required' : null,
                    ),
                    const SizedBox(height: 16),

                    _buildLabel(context, 'Ministry / Department'),
                    _buildTextField(
                      controller: _ministryController,
                      hint: 'e.g. Media, Choir, Youth Ministry',
                      icon: Icons.work_outline,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Ministry name is required' : null,
                    ),
                    const SizedBox(height: 16),

                    _buildLabel(context, 'Name of Church'),
                    _buildTextField(
                      controller: _churchController,
                      hint: 'Enter your local church branch',
                      icon: Icons.church_outlined,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Church name is required' : null,
                    ),
                    const SizedBox(height: 16),

                    _buildLabel(context, 'Email Address'),
                    _buildTextField(
                      controller: _emailController,
                      hint: 'example@domain.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email address is required';
                        }
                        final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                        if (!emailRegex.hasMatch(v.trim())) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildLabel(context, 'Phone Number (WhatsApp)'),
                    _buildTextField(
                      controller: _phoneController,
                      hint: 'e.g. +234 801 234 5678',
                      icon: Icons.phone_android_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Phone number is required' : null,
                    ),
                    const SizedBox(height: 28),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          elevation: 2,
                        ),
                        onPressed: _isSubmitting ? null : _submitForm,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Get Started',
                                style: SacredTypography.labelLg(context).copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, left: 4.0),
      child: Text(
        text,
        style: SacredTypography.labelSm(context).copyWith(
          fontWeight: FontWeight.bold,
          color: SacredColors.onBackground.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    final isDark = AppSettings.instance.isDarkMode;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: SacredTypography.bodyMd(context).copyWith(
        color: SacredColors.onBackground,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: SacredTypography.bodyMd(context).copyWith(
          color: SacredColors.onBackground.withOpacity(0.4),
        ),
        prefixIcon: Icon(icon, color: SacredColors.primary.withOpacity(0.6), size: 20),
        filled: true,
        fillColor: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(
            color: SacredColors.outlineVariant,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(
            color: SacredColors.outlineVariant.withOpacity(0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(
            color: SacredColors.primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(
            color: SacredColors.errorContainer,
          ),
        ),
      ),
    );
  }
}
