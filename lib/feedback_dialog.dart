import 'package:flutter/material.dart';
import 'dashboard_page.dart'; // For SacredColors, SacredTypography
import 'settings_state.dart';
import 'form_sync_service.dart';

class FeedbackDialog extends StatefulWidget {
  const FeedbackDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const FeedbackDialog(),
    );
  }

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final _feedbackController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    final feedbackText = _feedbackController.text.trim();
    final settings = AppSettings.instance;

    // Prepare payload (combines stored profile details for identification)
    final Map<String, String> payload = {
      'entry.1018809924': settings.userName,
      'entry.2069631626': settings.userMinistry,
      'entry.848809228': settings.userChurch,
      'entry.1802905149': settings.userEmail,
      'entry.1118608889': settings.userPhone,
      'entry.200104713': feedbackText, // FEEDBACK
    };

    // Queue submission
    await FormSyncService.instance.queueSubmission(payload);

    // Save prompt time
    settings.lastFeedbackPromptTime = DateTime.now();
    await settings.saveSettingsImmediately();

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Thank you for your feedback!',
            style: SacredTypography.bodyMd(context).copyWith(color: Colors.white),
          ),
          backgroundColor: SacredColors.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _skipFeedback() {
    final settings = AppSettings.instance;
    settings.lastFeedbackPromptTime = DateTime.now();
    settings.saveSettings();

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppSettings.instance.isDarkMode;
    final primaryColor = SacredColors.primary;
    final surfaceColor = SacredColors.surfaceContainer;
    final onSurfaceColor = SacredColors.onBackground;

    return Dialog(
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
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.rate_review_outlined,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Share Your Feedback',
                        style: SacredTypography.headlineMd(context).copyWith(
                          fontWeight: FontWeight.bold,
                          color: onSurfaceColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'How is your experience with Live-Deck? Tell us what you like or what we can improve. Your feedback helps us build a better tool for the ministry.',
                  style: SacredTypography.bodyMd(context).copyWith(
                    color: onSurfaceColor.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 20),

                // Feedback Field
                TextFormField(
                  controller: _feedbackController,
                  maxLines: 5,
                  minLines: 3,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Please enter some feedback comments' : null,
                  style: SacredTypography.bodyMd(context).copyWith(
                    color: onSurfaceColor,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type your feedback here...',
                    hintStyle: SacredTypography.bodyMd(context).copyWith(
                      color: onSurfaceColor.withOpacity(0.4),
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.8),
                    contentPadding: const EdgeInsets.all(16.0),
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
                        color: primaryColor,
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
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      onPressed: _isSubmitting ? null : _skipFeedback,
                      child: Text(
                        'Skip',
                        style: SacredTypography.labelLg(context).copyWith(
                          color: onSurfaceColor.withOpacity(0.6),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        elevation: 1,
                      ),
                      onPressed: _isSubmitting ? null : _submitFeedback,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Submit',
                              style: SacredTypography.labelLg(context).copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
