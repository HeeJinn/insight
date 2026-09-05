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

  Future<void> _openPrivacyPolicy() async {
    final accepted = await context.push<bool>('/privacy');
    if (accepted == true && mounted) {
      setState(() => _acceptedPrivacy = true);
    }
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

    final isLastStep = _index == pages.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome'),
        actions: [
          if (!isLastStep)
            TextButton(
              onPressed: () {
                _controller.jumpToPage(pages.length - 1);
              },
              child: const Text('Skip'),
            ),
        ],
      ),
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
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        height: 6,
                        decoration: BoxDecoration(
                          color: _index == i
                              ? context.appColors.accentDark
                              : context.appColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (isLastStep)
                  AppPanel(
                    radius: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Row(
                      children: [
                        Checkbox(
                          value: _acceptedPrivacy,
                          onChanged: (v) => setState(() => _acceptedPrivacy = v ?? false),
                        ),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () =>
                                setState(() => _acceptedPrivacy = !_acceptedPrivacy),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'I agree to the privacy policy and local data usage.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _openPrivacyPolicy,
                          child: const Text('Read policy'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_index > 0) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _controller.previousPage(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                          ),
                          child: const Text('Back'),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!isLastStep) {
                            await _controller.nextPage(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                            );
                            return;
                          }
                          if (!_acceptedPrivacy) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Please agree to the privacy policy to continue.',
                                ),
                                behavior: SnackBarBehavior.floating,
                                action: SnackBarAction(
                                  label: 'Read Policy',
                                  onPressed: _openPrivacyPolicy,
                                ),
                              ),
                            );
                            return;
                          }
                          await ref
                              .read(appStateControllerProvider)
                              .completeOnboarding(acceptedPrivacy: true);
                          if (!context.mounted) return;
                          context.go('/');
                        },
                        child: Text(!isLastStep ? 'Next' : 'Start'),
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
                  backgroundColor: context.appColors.accentSoft,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: context.appColors.accentDark,
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
