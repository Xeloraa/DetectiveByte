import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Rounded speech bubble for Detective Byte dialogue.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: text.isNotEmpty ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: AnimatedSlide(
        offset: text.isNotEmpty ? Offset.zero : const Offset(0, 0.1),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: text.isEmpty
            ? const SizedBox.shrink()
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  CustomPaint(
                    size: const Size(18, 9),
                    painter: _BubbleTailPainter(),
                  ),
                ],
              ),
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2 - 7, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width / 2 + 7, 0)
      ..close();

    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
