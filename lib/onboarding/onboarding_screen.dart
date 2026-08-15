import 'package:flutter/material.dart';

import '../companion/widgets/detective_byte_character.dart';
import '../core/theme/app_theme.dart';

class _OnboardingStep {
  const _OnboardingStep({
    required this.title,
    required this.subtitle,
    required this.pose,
    required this.stepNumber,
  });

  final String title;
  final String subtitle;
  final BytePose pose;
  final int stepNumber;
}

/// First-launch "How it works" carousel — shown once before the companion.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onFinished,
  });

  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _page = 0;

  static const _steps = [
    _OnboardingStep(
      stepNumber: 1,
      title: 'Byte is idle on your screen.',
      subtitle: 'Move him anywhere you want!',
      pose: BytePose(),
    ),
    _OnboardingStep(
      stepNumber: 2,
      title: 'Click on Byte.',
      subtitle: "He's ready to help!",
      pose: BytePose(
        scale: 1.08,
        leanForward: 0.12,
        magnifierRaise: 1.0,
        headTilt: -0.05,
      ),
    ),
    _OnboardingStep(
      stepNumber: 3,
      title: 'Byte analyzes the content.',
      subtitle: 'He looks for clues, context, and hidden details.',
      pose: BytePose(
        leanForward: 0.1,
        magnifierRaise: 1.0,
        headTilt: -0.04,
      ),
    ),
    _OnboardingStep(
      stepNumber: 4,
      title: 'Mission Completed!',
      subtitle: 'You learn the truth together. New missions await!',
      pose: BytePose(
        scale: 1.05,
        thumbsUp: 1,
        wink: 1,
      ),
    ),
  ];

  bool get _isLast => _page >= _steps.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      widget.onFinished();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.parchment,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.pets_rounded,
                    color: AppTheme.foxOrange,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'How it works',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink,
                        ),
                  ),
                  const Spacer(),
                  if (!_isLast)
                    TextButton(
                      onPressed: widget.onFinished,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: AppTheme.inkSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _steps.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return _OnboardingPage(step: step);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_steps.length, (index) {
                      final active = index == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 18 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? AppTheme.coatBrown
                              : AppTheme.parchmentDark,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.coatBrown,
                        foregroundColor: AppTheme.foxCream,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _isLast ? 'Get started' : 'Next',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.step});

  final _OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 1),
          Container(
            width: double.infinity,
            // Compact padding + a scaled-down Byte keep the whole page
            // inside short viewports (the old 230px-tall full-size Byte
            // plus headings overflowed anything under ~640px tall — the
            // test harness's default 800x600 surface tripped it every run).
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: AppTheme.darkPanel.copyWith(
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.accentGreen, width: 1.5),
                  ),
                  child: Text(
                    '${step.stepNumber}',
                    style: const TextStyle(
                      color: AppTheme.accentGreen,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 168,
                  child: Center(
                    child: Transform.scale(
                      scale: 0.72,
                      child: DetectiveByteCharacter(pose: step.pose),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            step.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.inkSoft,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
