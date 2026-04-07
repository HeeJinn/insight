import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../app_theme.dart';
import '../providers/app_state_provider.dart';
import '../widgets/app_chrome.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;
  bool _acceptedPrivacy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = const [
      _OnboardStep(
        title: 'Fast attendance',
        body: 'Register students, then run kiosk scanning for offline attendance.',
        animationAsset: 'assets/animations/Onboarding Kit.json',
      ),
      _OnboardStep(
        title: 'Privacy first',
        body: 'All recognition data is processed on-device and stored locally.',
        animationAsset: 'assets/animations/Login.json',
      ),
      _OnboardStep(
        title: 'Ready to start',
        body: 'Use Admin, Kiosk, Insights, and Sessions for your daily workflow.',
        animationAsset: 'assets/animations/User Profile.json',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: AppPanel(
                    radius: 18,
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: pages.length,
                      onPageChanged: (value) => setState(() => _index = value),
                      itemBuilder: (context, idx) => pages[idx],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(
                    pages.length,
                    (i) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        height: 6,
                        decoration: BoxDecoration(
                          color: _index == i ? AppTheme.accentDark : AppTheme.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_index == pages.length - 1)
                  AppPanel(
                    radius: 16,
                    padding: const EdgeInsets.all(12),
                    color: AppTheme.surface,
                    child: Row(
                      children: [
                        Checkbox(
                          value: _acceptedPrivacy,
                          onChanged: (v) => setState(() => _acceptedPrivacy = v ?? false),
                        ),
                        const Expanded(
                          child: Text('I agree to the privacy policy and local data usage.'),
                        ),
                        TextButton(
                          onPressed: () => context.push('/privacy'),
                          child: const Text('Read policy'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_index > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _controller.previousPage(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                          ),
                          child: const Text('Back'),
                        ),
                      ),
                    if (_index > 0) const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_index < pages.length - 1) {
                            await _controller.nextPage(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                            );
                            return;
                          }
                          if (!_acceptedPrivacy) return;
                          await ref
                              .read(appStateControllerProvider)
                              .completeOnboarding(acceptedPrivacy: true);
                          if (!context.mounted) return;
                          context.go('/');
                        },
                        child: Text(_index < pages.length - 1 ? 'Next' : 'Start'),
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

class _OnboardStep extends StatelessWidget {
  final String title;
  final String body;
  final String animationAsset;

  const _OnboardStep({
    required this.title,
    required this.body,
    required this.animationAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 160,
              height: 160,
              child: Lottie.asset(
                animationAsset,
                repeat: true,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => CircleAvatar(
                  radius: 50,
                  backgroundColor: AppTheme.accentSoft,
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppTheme.accentDark,
                    size: 40,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
