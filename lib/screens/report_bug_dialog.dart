
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class ReportBugDialog extends StatefulWidget {
  const ReportBugDialog({super.key});

  @override
  State<ReportBugDialog> createState() => _ReportBugDialogState();
}

class _ReportBugDialogState extends State<ReportBugDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final ScrollController _scrollController;
  double _prevBottomInset = 0.0;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
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

    return MediaQuery.removeViewInsets(
      context: context,
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
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).size.height * 0.15,
                left: 16.0,
                right: 16.0,
                bottom: 24.0,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.85,
                    maxWidth: 500, // Add max width for desktop
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
                            LayoutBuilder(
                              builder: (context, constraints) {
                                // Calculate scale factor based on design width (392 is typical phone width)
                                final double scale = constraints.maxWidth / 392.0;
                                return Stack(
                                  children: [
                                    // Background image
                                    Image.asset(
                                      'assets/images/report_bug_bg.png',
                                      fit: BoxFit.contain,
                                    ),
                                    // Title TextField
                                    Positioned(
                                      left: 44 * scale,
                                      right: 44 * scale,
                                      top: 222 * scale,
                                      height: 40 * scale,
                                  child: Container(
                                    color: Colors.transparent,
                                    child: TextField(
                                      controller: _titleCtrl,
                                      cursorColor: const Color.fromARGB(89, 0, 0, 0),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'Short summary of the problem',
                                        hintStyle: TextStyle(
                                            fontFamily: 'CanvaSans',
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Color.fromARGB(118, 44, 44, 44)),
                                      ),
                                      style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                                    ),
                                  ),
                                ),
                                    // Description TextField
                                    Positioned(
                                      left: 44 * scale,
                                      right: 44 * scale,
                                      top: 290 * scale,
                                      height: 200 * scale,
                                  child: Container(
                                    color: Colors.transparent,
                                    child: TextField(
                                      controller: _descCtrl,
                                      maxLines: null,
                                      keyboardType: TextInputType.multiline,
                                      cursorColor: Colors.black,
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'Provide details about the problem you encountered.',
                                        hintStyle: TextStyle(
                                          fontFamily: 'CanvaSans',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color.fromARGB(118, 44, 44, 44),
                                        ),
                                      ),
                                      style: const TextStyle(color: Colors.black),
                                    ),
                                  ),
                                ),
                                    // Submit button overlay
                                    Positioned(
                                      left: 40 * scale,
                                      right: 33 * scale,
                                      top: 460 * scale,
                                      height: 31 * scale,
                                  child: Material(
                                    color: const Color.fromARGB(0, 76, 175, 92),
                                    borderRadius: BorderRadius.circular(8),
                                    child: InkWell(
                                      onTap: () {
                                        FocusScope.of(context).unfocus();
                                        final messenger = ScaffoldMessenger.of(context);
                                        messenger.showSnackBar(const SnackBar(content: Text('Report submitted')));
                                        Navigator.of(context).pop();
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      splashColor: Colors.black26,
                                      child: Container(),
                                    ),
                                  ),
                                ),
                                    // Cancel button overlay
                                    Positioned(
                                      left: 40 * scale,
                                      right: 33 * scale,
                                      top: 507 * scale,
                                      height: 31 * scale,
                                  child: Material(
                                    borderRadius: BorderRadius.circular(8),
                                    color: const Color.fromARGB(0, 0, 0, 0),
                                    child: InkWell(
                                      onTap: () {
                                        FocusScope.of(context).unfocus();
                                        Navigator.of(context).pop();
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      splashColor: Colors.black26,
                                      child: Container(),
                                    ),
                                  ),
                                ),
                                  ],
                                );
                              },
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
    );
  }
}
