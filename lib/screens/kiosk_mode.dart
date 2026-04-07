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

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
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
                                    padding: const EdgeInsets.all(24),
                                    gradient: AppTheme.accentGradient,
                                    borderColor: Colors.white.withValues(
                                      alpha: 0.25,
                                    ),
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
                            SizedBox(height: compact ? 14 : 18),
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
        const AppPillTag(
          label: 'Live kiosk recognition',
          backgroundColor: Color(0x26FFFFFF),
          foregroundColor: Colors.white,
        ),
        const SizedBox(height: 18),
        Text(
          'Kiosk Mode',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            color: Colors.white,
            fontSize: 34,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Center the student in the frame, hold steady for a moment, and attendance will be logged after a successful match.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.92),
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            AppPillTag(
              label: '$studentCount students ready',
              icon: Icons.groups_2_outlined,
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              foregroundColor: Colors.white,
            ),
            AppPillTag(
              label: '$attendanceCount logs stored',
              icon: Icons.event_note_outlined,
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              foregroundColor: Colors.white,
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppPillTag(
                      label: 'Live kiosk recognition',
                      backgroundColor: AppTheme.accentSoft,
                      foregroundColor: AppTheme.accentDark,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Kiosk Mode',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                onPressed: () => context.go('/admin'),
                style: IconButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  foregroundColor: AppTheme.ink,
                ),
                icon: const Icon(Icons.dashboard_customize_outlined),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => context.go('/settings'),
                style: IconButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  foregroundColor: AppTheme.ink,
                ),
                icon: const Icon(Icons.tune_outlined),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Center the face and hold still for live attendance.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              AppPillTag(
                label: '$studentCount ready',
                icon: Icons.groups_2_outlined,
                backgroundColor: AppTheme.accentSoft,
                foregroundColor: AppTheme.accentDark,
              ),
              AppPillTag(
                label: '$attendanceCount logs',
                icon: Icons.event_note_outlined,
                backgroundColor: AppTheme.blueSoft,
                foregroundColor: AppTheme.blue,
              ),
            ],
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
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.ink,
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
                  gradient: AppTheme.orangeGradient,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: AppTheme.panelShadow,
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
