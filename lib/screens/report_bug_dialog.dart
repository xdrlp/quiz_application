
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
          builder: (msgContext) => MediaQuery.removeViewInsets(
            context: msgContext,
            removeBottom: true,
            child: Stack(
              children: [
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(msgContext).size.height * 0.85,
                        ),
                        child: Material(
                        color: Colors.transparent,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              physics: isKeyboardOpen ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Stack(
                                    children: [
                                      // Background image
                                      Image.asset(
                                        'assets/images/report_bug_bg.png',
                                        fit: BoxFit.contain,
                                      ),
                                      
                                      // Name TextField
                                      Positioned(
                                        left: 45,
                                        right: 39,
                                        top: 223, // Adjust this value to align with the background image
                                        height: 40,
                                        child: Container(
                                          color: Colors.transparent,
                                          child: TextField(
                                            controller: _nameCtrl,
                                            cursorColor: const Color.fromARGB(89, 0, 0, 0),
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              hintText: 'Enter your full name',
                                              hintStyle: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color.fromARGB(118, 44, 44, 44)),
                                            ),
                                            style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                                          ),
                                        ),
                                      ),
                                      
                                      // Email TextField
                                      Positioned(
                                        left: 45,
                                        right: 39,
                                        top: 296, // Adjust this value to align with the background image
                                        height: 35,
                                        child: Container(
                                          color: Colors.transparent,
                                          child: TextField(
                                            controller: _emailCtrl,
                                            keyboardType: TextInputType.emailAddress,
                                            cursorColor: const Color.fromARGB(89, 0, 0, 0),
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              hintText: 'Enter your email adress',
                                              hintStyle: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color.fromARGB(118, 44, 44, 44)),
                                            ),
                                            style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                                          ),
                                        ),
                                      ),

                                      // Title TextField
                                      Positioned(
                                        left: 45,
                                        right: 39,
                                        top: 364,
                                        height: 35,
                                        child: Container(
                                          color: const Color.fromARGB(0, 0, 0, 0),
                                          child: TextField(
                                            controller: _titleCtrl,
                                            cursorColor: const Color.fromARGB(89, 0, 0, 0),
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              hintText: 'Short summary of the problem',
                                              hintStyle: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color.fromARGB(118, 44, 44, 44)),
                                            ),
                                            style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                                          ),
                                        ),
                                      ),
                                      // Description TextField
                                      Positioned(
                                        left: 45,
                                        right: 39,
                                        top: 436,
                                        height: 140,
                                        child: Container(
                                          color: const Color.fromARGB(0, 0, 0, 0),
                                          child: TextField(
                                            controller: _descCtrl,
                                            maxLines: null,
                                            keyboardType: TextInputType.multiline,
                                            cursorColor: Colors.black,
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              hintText: 'Provide details about the problem you encountered.',
                                              hintStyle: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Color.fromARGB(118, 44, 44, 44),
                                              ),
                                            ),
                                            style: const TextStyle(color: Colors.black),
                                          ),
                                        ),
                                      ),
                                      // Submit button overlay
                                      Positioned(
                                        left: 37,
                                        right: 33,
                                        top: 610,
                                        height: 31,
                                        child: Material(
                                          color: const Color.fromARGB(0, 0, 0, 0),
                                          borderRadius: BorderRadius.circular(8),
                                          child: InkWell(
                                            onTap: _isSubmitting
                                                ? null
                                                : () async {
                                                    FocusScope.of(msgContext).unfocus();
                                                    await _submitReport();
                                                  },
                                            borderRadius: BorderRadius.circular(8),
                                            splashColor: Colors.black26,
                                            child: Container(),
                                          ),
                                        ),
                                      ),
                                      // Cancel button overlay
                                      Positioned(
                                        left: 37,
                                        right: 36,
                                        top: 657,
                                        height: 31,
                                        child: Material(
                                          borderRadius: BorderRadius.circular(8),
                                          color: const Color.fromARGB(0, 0, 0, 0),
                                          child: InkWell(
                                            onTap: () {
                                              FocusScope.of(msgContext).unfocus();
                                              Navigator.of(msgContext).pop();
                                            },
                                            borderRadius: BorderRadius.circular(8),
                                            splashColor: Colors.black26,
                                            child: Container(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Extra space at bottom for scrolling when keyboard opens
                                  const SizedBox(height: 300),
                                ],
                              ),
                            ),
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
      ),
    );
  }
}
