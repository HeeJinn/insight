import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../app_theme.dart';
import '../providers/hive_provider.dart';
import '../widgets/app_chrome.dart';
import '../widgets/camera_scanner.dart';
import '../widgets/responsive_utils.dart';
import 'unsupported_screen.dart';

class KioskMode extends ConsumerWidget {
  const KioskMode({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsBoxProvider);
    final attendanceAsync = ref.watch(attendanceBoxProvider);

    if (kIsWeb) {
      return const UnsupportedPlatformScreen(featureName: 'Kiosk Mode');
    }

    void handleBack() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: handleBack,
          ),
          title: const Text('Kiosk'),
        ),
        body: AppBackground(
        child: studentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _KioskStateMessage(message: 'Error: $error'),
          data: (studentsBox) => attendanceAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) =>
                _KioskStateMessage(message: 'Error: $error'),
            data: (attendanceBox) => StreamBuilder(
              stream: studentsBox.watch(),
              builder: (context, _) => StreamBuilder(
                stream: attendanceBox.watch(),
                builder: (context, _) => LayoutBuilder(
                  builder: (context, constraints) {
                final width = constraints.maxWidth;
                final compact = AppBreakpoints.isCompact(width);
                final contentWidth = AppBreakpoints.contentWidth(width);
                final padding = AppBreakpoints.pagePadding(width);
                final hasStudents = studentsBox.isNotEmpty;

                return SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentWidth),
                      child: Padding(
                        padding: padding,
                        child: Column(
                          children: [
                            compact
                                ? _CompactKioskHeader(
                                    studentCount: studentsBox.length,
                                    attendanceCount: attendanceBox.length,
                                  )
                                : AppPanel(
                                    padding: const EdgeInsets.all(20),
                                    showReticles: true,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _KioskHeader(
                                            studentCount: studentsBox.length,
                                            attendanceCount:
                                                attendanceBox.length,
                                          ),
                                        ),
                                        const SizedBox(width: 22),
                                        const _KioskActions(vertical: true),
                                      ],
                                    ),
                                  ),
                            SizedBox(height: compact ? 12 : 16),
                            Expanded(
                              child: hasStudents
                                  ? AppPanel(
                                      padding: EdgeInsets.all(compact ? 10 : 14),
                                      child: CameraScanner(
                                        studentsBox: studentsBox,
                                        attendanceBox: attendanceBox,
                                      ),
                                    )
                                  : _KioskEmptyState(compact: compact),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }
}

class _KioskHeader extends StatelessWidget {
  final int studentCount;
  final int attendanceCount;

  const _KioskHeader({
    required this.studentCount,
    required this.attendanceCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'KIOSK MODE',
          style: AppleTypography.caption1.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: context.appColors.success,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Biometric Verification',
          style: AppleTypography.title1.copyWith(
            color: context.appColors.primaryText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Position face within camera viewfinder. Recognition logs timestamp automatically.',
          style: AppleTypography.subhead.copyWith(
            color: context.appColors.secondaryText,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              '$studentCount enrolled',
              style: AppleTypography.footnote.copyWith(
                color: context.appColors.secondaryText,
                fontFeatures: AppleTypography.tabular,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '·',
              style: TextStyle(
                color: context.appColors.secondaryText,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$attendanceCount check-ins',
              style: AppleTypography.footnote.copyWith(
                color: context.appColors.secondaryText,
                fontFeatures: AppleTypography.tabular,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompactKioskHeader extends StatelessWidget {
  final int studentCount;
  final int attendanceCount;

  const _CompactKioskHeader({
    required this.studentCount,
    required this.attendanceCount,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      radius: 12,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KIOSK ACTIVE',
                  style: AppleTypography.caption2.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: context.appColors.success,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Face Scanner',
                  style: AppleTypography.headline.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.appColors.primaryText,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$attendanceCount logged',
            style: AppleTypography.footnote.copyWith(
              color: context.appColors.secondaryText,
              fontFeatures: AppleTypography.tabular,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => context.go('/admin'),
            icon: const Icon(Icons.dashboard_customize_outlined, size: 20),
            tooltip: 'Admin',
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.tune_outlined, size: 20),
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _KioskActions extends StatelessWidget {
  final bool vertical;

  const _KioskActions({required this.vertical});

  @override
  Widget build(BuildContext context) {
    final admin = ElevatedButton.icon(
      onPressed: () => context.go('/admin'),
      style: ElevatedButton.styleFrom(
        backgroundColor: context.appColors.button,
        foregroundColor: context.appColors.buttonText,
      ),
      icon: const Icon(Icons.dashboard_customize_outlined),
      label: const Text('Admin Dashboard'),
    );

    final settings = OutlinedButton.icon(
      onPressed: () => context.go('/settings'),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
      ),
      icon: const Icon(Icons.tune_outlined),
      label: const Text('Settings'),
    );

    if (vertical) {
      return SizedBox(
        width: 250,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [admin, const SizedBox(height: 12), settings],
        ),
      );
    }

    return Row(
      children: [
        Expanded(child: admin),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.tune_outlined),
            label: const Text('Settings'),
          ),
        ),
      ],
    );
  }
}

class _KioskEmptyState extends StatelessWidget {
  final bool compact;

  const _KioskEmptyState({required this.compact});

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  gradient: context.appDecorations.orangeGradient,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: context.appDecorations.panelShadow,
                ),
                child: const Icon(
                  Icons.person_search_outlined,
                  size: 36,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No student profiles available yet',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Register at least one student before starting live recognition so kiosk mode has local profiles to compare against.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: compact ? double.infinity : 260,
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/admin'),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Open Registration'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KioskStateMessage extends StatelessWidget {
  final String message;

  const _KioskStateMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AppPanel(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
