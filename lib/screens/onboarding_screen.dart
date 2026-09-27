import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/admin_lock_provider.dart';
import '../providers/app_state_provider.dart';
import '../ui/insight_ui.dart';

enum _Step { welcome, privacy, pin, done }

/// First-run setup, like Apple's setup assistant: what Insight does, the
/// privacy agreement, the admin PIN, and where to go next.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  _Step _step = _Step.welcome;
  bool _forward = true;
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  final _confirmFocus = FocusNode();
  String? _pinError;

  static const _minPinLength = 4;

  /// The kiosk at the door needs a PIN; on a phone it can wait.
  bool get _pinRequired => isDesktopPlatform;

  @override
  void initState() {
    super.initState();
    _pin.addListener(_clearPinError);
    _confirm.addListener(_clearPinError);
  }

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  /// Typing clears any error and re-evaluates whether Continue is enabled.
  void _clearPinError() => setState(() => _pinError = null);

  void _go(_Step step) {
    HapticFeedback.selectionClick();
    setState(() {
      _forward = step.index > _step.index;
      _step = step;
    });
  }

  Future<void> _readPolicy() async {
    final accepted = await context.push<bool>('/privacy');
    if (accepted == true && mounted) _go(_Step.pin);
  }

  Future<void> _savePin() async {
    final pin = _pin.text.trim();
    if (pin.length < _minPinLength) {
      setState(() => _pinError = 'Use at least $_minPinLength digits.');
      return;
    }
    if (pin != _confirm.text.trim()) {
      HapticFeedback.heavyImpact();
      setState(() => _pinError = "The PINs don't match.");
      return;
    }
    await ref.read(adminLockControllerProvider).setPin(pin);
    if (mounted) _go(_Step.done);
  }

  Future<void> _finish() async {
    final lock = ref.read(adminLockControllerProvider);
    // The admin just set things up; let them keep going instead of locking
    // them out behind the PIN they just made.
    lock.unlock();
    await ref
        .read(appStateControllerProvider)
        .completeOnboarding(acceptedPrivacy: true);
    if (mounted) context.go('/admin/today');
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (_step) {
      _Step.welcome => _Page(
        key: const ValueKey(_Step.welcome),
        hero: const _AppMark(),
        title: 'Welcome to Insight',
        message: 'Attendance by face, right at the classroom door.',
        content: const _FeatureList(),
        primary: ('Continue', () => _go(_Step.privacy)),
      ),
      _Step.privacy => _Page(
        key: const ValueKey(_Step.privacy),
        hero: SymbolBadge(
          CupertinoIcons.lock_shield_fill,
          InsightColors.accent.resolveFrom(context),
          size: 72,
        ),
        title: 'Your Data Stays Here',
        message:
            'Face profiles and attendance are stored only on this device and '
            'never uploaded. Only an admin can export records.',
        primary: ('Agree & Continue', () => _go(_Step.pin)),
        secondary: ('Read Privacy Policy', _readPolicy),
      ),
      _Step.pin => _Page(
        key: const ValueKey(_Step.pin),
        hero: SymbolBadge(
          CupertinoIcons.lock_fill,
          CupertinoColors.systemGrey.resolveFrom(context),
          size: 72,
        ),
        title: 'Create an Admin PIN',
        message: _pinRequired
            ? 'The kiosk runs at the door. This PIN keeps students out of the '
                  'admin area.'
            : 'Protects the admin area when the kiosk is running.',
        content: _PinFields(
          pin: _pin,
          confirm: _confirm,
          confirmFocus: _confirmFocus,
          error: _pinError,
          onSubmit: _savePin,
        ),
        primary: (
          'Continue',
          _pin.text.isEmpty || _confirm.text.isEmpty ? null : _savePin,
        ),
        secondary: _pinRequired
            ? null
            : ('Set Up Later', () => _go(_Step.done)),
      ),
      _Step.done => _Page(
        key: const ValueKey(_Step.done),
        hero: Icon(
          CupertinoIcons.checkmark_circle_fill,
          size: 80,
          color: InsightColors.success.resolveFrom(context),
        ),
        title: "You're All Set",
        message: 'Three things get the kiosk ready:',
        content: const _NextSteps(),
        primary: ('Get Started', _finish),
      ),
    };

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: false,
        border: null,
        backgroundColor: const Color(0x00000000),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
        leading: _step == _Step.welcome || _step == _Step.done
            ? null
            : Align(
                widthFactor: 1,
                child: GlassIconButton(
                  icon: CupertinoIcons.chevron_back,
                  semanticLabel: 'Back',
                  size: 40,
                  onPressed: () => _go(_Step.values[_step.index - 1]),
                ),
              ),
        middle: _StepDots(index: _step.index, count: _Step.values.length),
      ),
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final incoming = child.key == ValueKey(_step);
            final dx = (incoming == _forward) ? 0.08 : -0.08;
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: Offset(dx, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: body,
        ),
      ),
    );
  }
}

/// One setup page: a hero, a title and line of explanation, optional
/// content, and the page's actions pinned at the bottom.
class _Page extends StatelessWidget {
  const _Page({
    super.key,
    required this.hero,
    required this.title,
    required this.message,
    required this.primary,
    this.content,
    this.secondary,
  });

  final Widget hero;
  final String title;
  final String message;
  final Widget? content;
  final (String, VoidCallback?) primary;
  final (String, VoidCallback)? secondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 28),
                      Center(child: hero),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: InsightText.largeTitle.copyWith(
                          color: InsightColors.label.resolveFrom(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: InsightText.body.copyWith(
                          color: InsightColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                      if (content != null) ...[
                        const SizedBox(height: 28),
                        content!,
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              CupertinoButton.filled(
                sizeStyle: CupertinoButtonSize.large,
                borderRadius: BorderRadius.circular(InsightRadii.capsule),
                onPressed: primary.$2,
                child: Text(primary.$1),
              ),
              if (secondary != null)
                CupertinoButton(
                  onPressed: secondary!.$2,
                  child: Text(
                    secondary!.$1,
                    style: InsightText.body.copyWith(
                      color: InsightColors.accent.resolveFrom(context),
                    ),
                  ),
                )
              else
                const SizedBox(height: 44),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: InsightColors.accent.resolveFrom(context),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Icon(
        CupertinoIcons.viewfinder,
        size: 48,
        color: CupertinoColors.white,
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${index + 1} of $count',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 18 : 7,
              height: 7,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(InsightRadii.capsule),
                color: i == index
                    ? InsightColors.accent.resolveFrom(context)
                    : InsightColors.fill.resolveFrom(context),
              ),
            ),
        ],
      ),
    );
  }
}

/// Apple-style feature rows: a tinted symbol, a bold line, a short detail.
class _FeatureList extends StatelessWidget {
  const _FeatureList();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _Feature(
          icon: CupertinoIcons.viewfinder,
          color: CupertinoColors.systemBlue,
          title: 'Contactless Check-in',
          detail: 'Students step up to the kiosk and look at the camera.',
        ),
        _Feature(
          icon: CupertinoIcons.lock_shield_fill,
          color: CupertinoColors.systemGreen,
          title: 'Stays on This Device',
          detail: 'Recognition runs offline. Nothing is uploaded.',
        ),
        _Feature(
          icon: CupertinoIcons.chart_bar_fill,
          color: CupertinoColors.systemOrange,
          title: 'Attendance at a Glance',
          detail: 'See who is in, who is late, and trends over time.',
        ),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final CupertinoDynamicColor color;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Icon(icon, size: 32, color: color.resolveFrom(context)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: InsightText.headline.copyWith(
                    color: InsightColors.label.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: InsightText.subheadline.copyWith(
                    color: InsightColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PinFields extends StatelessWidget {
  const _PinFields({
    required this.pin,
    required this.confirm,
    required this.confirmFocus,
    required this.error,
    required this.onSubmit,
  });

  final TextEditingController pin;
  final TextEditingController confirm;
  final FocusNode confirmFocus;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final danger = InsightColors.danger.resolveFrom(context);
    Widget field(
      TextEditingController c,
      String placeholder, {
      FocusNode? focus,
      bool autofocus = false,
      required ValueChanged<String> onSubmitted,
    }) => CupertinoTextField(
      controller: c,
      focusNode: focus,
      autofocus: autofocus,
      placeholder: placeholder,
      decoration: null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      obscureText: true,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 8,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.next,
      onSubmitted: onSubmitted,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRSuperellipse(
          borderRadius: BorderRadius.circular(InsightRadii.section),
          child: ColoredBox(
            color: InsightColors.card.resolveFrom(context),
            child: Column(
              children: [
                field(
                  pin,
                  'PIN (4–8 digits)',
                  autofocus: true,
                  onSubmitted: (_) => confirmFocus.requestFocus(),
                ),
                Container(
                  height: 0.5,
                  margin: const EdgeInsets.only(left: 16),
                  color: InsightColors.separator.resolveFrom(context),
                ),
                field(
                  confirm,
                  'Confirm PIN',
                  focus: confirmFocus,
                  onSubmitted: (_) => onSubmit(),
                ),
              ],
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_circle_fill,
                  size: 15,
                  color: danger,
                ),
                const SizedBox(width: 6),
                Text(
                  error!,
                  style: InsightText.footnote.copyWith(color: danger),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _NextSteps extends StatelessWidget {
  const _NextSteps();

  @override
  Widget build(BuildContext context) {
    return InsightListSection(
      margin: EdgeInsets.zero,
      children: [
        InsightRow(
          leading: SymbolBadge(
            CupertinoIcons.person_badge_plus_fill,
            CupertinoColors.systemBlue.resolveFrom(context),
          ),
          title: 'Enroll Students',
          subtitle: 'Five quick face photos each, in Students.',
        ),
        InsightRow(
          leading: SymbolBadge(
            CupertinoIcons.calendar,
            CupertinoColors.systemRed.resolveFrom(context),
          ),
          title: 'Add Your Schedule',
          subtitle: 'Class times in Sessions, so lateness is tracked.',
        ),
        InsightRow(
          leading: SymbolBadge(
            CupertinoIcons.viewfinder,
            CupertinoColors.systemGreen.resolveFrom(context),
          ),
          title: 'Start the Kiosk',
          subtitle: 'From the sidebar or Today, when class begins.',
        ),
      ],
    );
  }
}
