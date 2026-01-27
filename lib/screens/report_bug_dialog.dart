
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class ReportBugDialog extends StatefulWidget {
  final String screenName;

  const ReportBugDialog({super.key, this.screenName = 'unknown'});

  @override
  State<ReportBugDialog> createState() => _ReportBugDialogState();
}

class _ReportBugDialogState extends State<ReportBugDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final ScrollController _scrollController;
  double _prevBottomInset = 0.0;
  bool _isSubmitting = false;
  late final HttpsCallable _sendBugReportCallable;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _titleCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _scrollController = ScrollController();
    _sendBugReportCallable = FirebaseFunctions.instance.httpsCallable('sendBugReport');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final messenger = ScaffoldMessenger.of(context);
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final title = _titleCtrl.text.trim();
    final description = _descCtrl.text.trim();
    
    if (name.isEmpty || email.isEmpty || title.isEmpty || description.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please complete all fields before submitting.')),
      );
      return;
    }
    
    setState(() => _isSubmitting = true);
    try {
      await _sendBugReportCallable.call({
        'name': name,
        'email': email,
        'title': title,
        'description': description,
        'screen': widget.screenName,
        'userId': FirebaseAuth.instance.currentUser?.uid,
      });
      if (!mounted) return;

      const duration = Duration(seconds: 3);
      messenger.showSnackBar(
        SnackBar(
          duration: duration,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Report submitted successfully! Auto-closing...'),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: duration,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  valueColor: const AlwaysStoppedAnimation(Color.fromARGB(255, 0, 0, 0)),
                  backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
      );

      await Future.delayed(duration);
      if (!mounted) return;
      Navigator.of(context).pop();

    } on FirebaseFunctionsException catch (e) {
      final message = e.message ?? 'Unable to send the bug report.';
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('Unable to send the bug report.')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = bottomInset > 0;

    // Scroll back to top when keyboard closes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_prevBottomInset > 0 && bottomInset == 0) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      }
      _prevBottomInset = bottomInset;
    });

    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Builder(
          builder: (msgContext) => Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                  child: Container(color: Colors.transparent),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: isKeyboardOpen ? const ClampingScrollPhysics() : const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      left: 16, 
                      right: 16, 
                      bottom: isKeyboardOpen ? bottomInset + 20 : 20
                    ),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Color(0xFF181818), // #181818
                            Color(0xFFFFFFFF), // #ffffff
                            Color(0xFFC3B8B8), // #c3b8b8
                            Color(0xFFFFFFFF), // #ffffff
                            Color(0xFFFFFFFF), // #ffffff
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment(-1, -1),
                            end: Alignment(1, 1),
                            colors: [
                              Color.fromARGB(130, 255, 255, 255), // White with 49% transparency
                              Color.fromARGB(228, 155, 155, 155), // #9b9b9b with 10.5% transparency
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 15,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 20),
                            // Bug Icon Circle
                            Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF666666),
                                  Color(0xFF999999),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(2, 2),
                                  spreadRadius: 0,
                                ),
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(-2, -2),
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.bug_report, size: 32, color: Colors.black54),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Report a bug',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Please tell us what went wrong.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Dashed Line
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              children: List.generate(30, (index) => Expanded(
                                child: Container(
                                  height: 1,
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  color: Colors.black26,
                                ),
                              )),
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Form Fields
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildLabel('Name*'),
                                _buildTextField(
                                  controller: _nameCtrl,
                                  hint: 'Enter your full name',
                                ),
                                const SizedBox(height: 12),
                                _buildLabel('Email*'),
                                _buildTextField(
                                  controller: _emailCtrl,
                                  hint: 'Enter your email address',
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 12),
                                _buildLabel('Title*'),
                                _buildTextField(
                                  controller: _titleCtrl,
                                  hint: 'Short summary of the problem',
                                ),
                                const SizedBox(height: 12),
                                _buildLabel('Description*'),
                                _buildTextField(
                                  controller: _descCtrl,
                                  hint: 'Provide details about the problem you encountered.',
                                  maxLines: 5,
                                  height: 120,
                                ),
                                const SizedBox(height: 24),
                                
                                // Buttons
                                _buildButton(
                                  text: 'Submit',
                                  onTap: _isSubmitting 
                                    ? null 
                                    : () async {
                                        FocusScope.of(msgContext).unfocus();
                                        await _submitReport();
                                      },
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Color(0xFFE0E0E0), Color(0xFFAAAAAA)],
                                  ),
                                  textColor: Colors.black87,
                                ),
                                const SizedBox(height: 12),
                                _buildButton(
                                  text: 'Cancel',
                                  onTap: () {
                                    FocusScope.of(msgContext).unfocus();
                                    Navigator.of(msgContext).pop();
                                  },
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Color(0xFFFF3333), Color(0xFFCC0000)],
                                  ),
                                  textColor: Colors.white,
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ],
                      ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 4),
      child: RichText(
        text: TextSpan(
          text: text.substring(0, text.length - 1),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
          children: [
            TextSpan(
              text: text.substring(text.length - 1),
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int? maxLines = 1,
    double? height,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF000000), // #000000
            Color(0xFF484848), // #484848
            Color(0xFFFFFDFD), // #fffdfd
            Color(0xFFD5D5D5), // #d5d5d5
            Color(0xFF7C7979), // #7c7979
            Color(0xFFFFFFFF), // #ffffff
            Color(0xFFFFFFFF), // #ffffff
          ],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          cursorColor: Colors.black54,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          decoration: InputDecoration(
            border: InputBorder.none,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0x8A000000),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required VoidCallback? onTap,
    required Gradient gradient,
    required Color textColor,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
