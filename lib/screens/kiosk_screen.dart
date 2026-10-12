import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';

import '../models/attendance.dart';
import '../models/session_entry.dart';
import '../models/student.dart';
import '../providers/admin_lock_provider.dart';
import '../providers/hive_provider.dart';
import '../providers/sessions_provider.dart';
import '../providers/settings_provider.dart';
import '../services/session_clock.dart';
import '../ui/insight_ui.dart';
import '../widgets/admin_unlock_dialog.dart';
import '../widgets/camera_scanner.dart';

/// The contactless check-in screen on the computer at the classroom door:
/// the camera on the left, the student's result on the right. Nobody
/// touches it; it changes on its own and resets after a few seconds.
class KioskScreen extends ConsumerStatefulWidget {
  const KioskScreen({super.key});

  @override
  ConsumerState<KioskScreen> createState() => _KioskScreenState();
}

class _KioskScreenState extends ConsumerState<KioskScreen> {
  ScanEvent? _event;
  Timer? _eventTimer;
  Timer? _minuteTimer;
  DateTime _now = DateTime.now();

  static const _eventHold = Duration(milliseconds: 3500);

  @override
  void initState() {
    super.initState();
    // The active session and "next class" depend on the clock.
    _minuteTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _eventTimer?.cancel();
    _minuteTimer?.cancel();
    super.dispose();
  }

  void _onScanEvent(ScanEvent event) {
    if (event.kind == ScanEventKind.checkedIn &&
        ref.read(soundFeedbackProvider)) {
      SystemSound.play(SystemSoundType.alert);
    }
    setState(() {
      _event = event;
      _now = DateTime.now();
    });
    _eventTimer?.cancel();
    _eventTimer = Timer(_eventHold, () {
      if (mounted) setState(() => _event = null);
    });
  }

  Future<void> _openAdmin() async {
    // Phones and tablets have no kiosk-first flow, so the admin is already
    // signed in there.
    final unlocked =
        ref.read(adminUnlockedProvider) || await showAdminUnlockDialog(context);
    if (unlocked && mounted) context.go('/admin/today');
  }

  bool get _usesCommandKey =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  /// Debug builds only: F7–F10 fake a check-in, a repeat check-in, an
  /// unknown face and a student off the class list, so the result states
  /// can be reviewed without a camera.
  Map<ShortcutActivator, VoidCallback> get _debugShortcuts {
    if (!kDebugMode) return const {};
    ScanEvent fake(ScanEventKind kind) {
      final student = Student(
        id: '2021-0042',
        name: 'Maria Santos',
        embeddings: [],
      );
      final at = DateTime.now();
      return ScanEvent(
        kind,
        student: student,
        at: at,
        attendance: Attendance(
          studentId: student.id,
          timestamp: kind == ScanEventKind.alreadyCheckedIn
              ? at.subtract(const Duration(minutes: 12))
              : at,
        ),
      );
    }

    SingleActivator key(LogicalKeyboardKey k) => SingleActivator(k);
    return {
      key(LogicalKeyboardKey.f7): () =>
          _onScanEvent(fake(ScanEventKind.checkedIn)),
      key(LogicalKeyboardKey.f8): () =>
          _onScanEvent(fake(ScanEventKind.alreadyCheckedIn)),
      key(LogicalKeyboardKey.f9): () =>
          _onScanEvent(const ScanEvent(ScanEventKind.unknown)),
      key(LogicalKeyboardKey.f10): () =>
          _onScanEvent(fake(ScanEventKind.notOnClassList)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsBoxProvider);
    final attendanceAsync = ref.watch(attendanceBoxProvider);
    final sessions = ref.watch(sessionsProvider);

    final Widget body;
    if (studentsAsync.hasError || attendanceAsync.hasError) {
      body = EmptyState(
        icon: CupertinoIcons.exclamationmark_triangle,
        title: "Can't Open Records",
        message: '${studentsAsync.error ?? attendanceAsync.error}',
      );
    } else if (studentsAsync.value == null || attendanceAsync.value == null) {
      body = const SizedBox.expand();
    } else {
      final studentsBox = studentsAsync.value!;
      final attendanceBox = attendanceAsync.value!;
      body = StreamBuilder(
        stream: studentsBox.watch(),
        builder: (context, _) => StreamBuilder(
          stream: attendanceBox.watch(),
          builder: (context, _) => _KioskLayout(
            studentsBox: studentsBox,
            attendanceBox: attendanceBox,
            sessions: sessions,
            now: _now,
            event: _event,
            onScanEvent: _onScanEvent,
            onOpenAdmin: _openAdmin,
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _openAdmin();
      },
      child: CallbackShortcuts(
        bindings: {
          // ⌘, on the Mac (Ctrl+, elsewhere) opens the admin area.
          SingleActivator(
            LogicalKeyboardKey.comma,
            meta: _usesCommandKey,
            control: !_usesCommandKey,
          ): _openAdmin,
          ..._debugShortcuts,
        },
        child: Focus(
          autofocus: true,
          child: CupertinoPageScaffold(child: body),
        ),
      ),
    );
  }
}

class _KioskLayout extends StatelessWidget {
  const _KioskLayout({
    required this.studentsBox,
    required this.attendanceBox,
    required this.sessions,
    required this.now,
    required this.event,
    required this.onScanEvent,
    required this.onOpenAdmin,
  });

  final Box<Student> studentsBox;
  final Box<Attendance> attendanceBox;
  final List<SessionEntry> sessions;
  final DateTime now;
  final ScanEvent? event;
  final ValueChanged<ScanEvent> onScanEvent;
  final VoidCallback onOpenAdmin;

  @override
  Widget build(BuildContext context) {
    final active = activeSessionAt(sessions, now);
    final next = nextSessionAfter(sessions, now);
    // With no schedule at all, the kiosk takes general check-ins. With a
    // schedule, it only takes them while a class is running.
    final scanning = sessions.isEmpty || active != null;

    final camera = ClipRRect(
      borderRadius: BorderRadius.circular(InsightRadii.card),
      child: Container(
        // A faint rim keeps the well's edge visible on a black dark-mode
        // page before the video arrives.
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(InsightRadii.card),
          border: Border.all(
            color: InsightColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
        color: const Color(0xFF0A0A0C),
        child: CameraScanner(
          studentsBox: studentsBox,
          attendanceBox: attendanceBox,
          onEvent: onScanEvent,
          enabled: scanning,
          pausedLabel: 'No class right now',
        ),
      ),
    );

    final panel = _InfoPanel(
      studentsBox: studentsBox,
      attendanceBox: attendanceBox,
      active: active,
      next: next,
      hasSchedule: sessions.isNotEmpty,
      now: now,
      event: event,
      onOpenAdmin: onOpenAdmin,
    );

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, c) {
          final landscape = c.maxWidth >= 760 && c.maxWidth > c.maxHeight * 0.9;
          const gap = 20.0;
          if (landscape) {
            final panelWidth = (c.maxWidth * 0.36).clamp(360.0, 500.0);
            return Padding(
              padding: const EdgeInsets.all(gap),
              child: Row(
                children: [
                  Expanded(child: camera),
                  const SizedBox(width: gap),
                  SizedBox(width: panelWidth, child: panel),
                ],
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(InsightSpacing.margin),
            child: Column(
              children: [
                Expanded(flex: 11, child: camera),
                const SizedBox(height: InsightSpacing.margin),
                Expanded(flex: 10, child: panel),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.studentsBox,
    required this.attendanceBox,
    required this.active,
    required this.next,
    required this.hasSchedule,
    required this.now,
    required this.event,
    required this.onOpenAdmin,
  });

  final Box<Student> studentsBox;
  final Box<Attendance> attendanceBox;
  final SessionEntry? active;
  final SessionEntry? next;
  final bool hasSchedule;
  final DateTime now;
  final ScanEvent? event;
  final VoidCallback onOpenAdmin;

  /// Today's check-ins for the running session (or general ones when there
  /// is no schedule), newest first.
  List<Attendance> get _todaysRecords {
    final title = active?.title;
    return attendanceBox.values
        .where((a) => isSameDay(a.timestamp, now) && a.sessionTitle == title)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  Widget build(BuildContext context) {
    final records = _todaysRecords;

    final Widget hero;
    if (event != null) {
      hero = _EventView(event: event!, session: active);
    } else if (studentsBox.isEmpty) {
      hero = const EmptyState(
        icon: CupertinoIcons.person_2,
        title: 'No Students Yet',
        message: 'An admin needs to enroll students before check-in starts.',
      );
    } else if (hasSchedule && active == null) {
      hero = EmptyState(
        icon: CupertinoIcons.moon_zzz,
        title: 'No Class Right Now',
        message: next == null
            ? 'Check-in opens when the next session starts.'
            : 'Next: ${next!.title} at ${formatMinuteOfDay(next!.startMinuteOfDay)}',
      );
    } else {
      hero = _IdleView(now: now, session: active);
    }

    // No list of who has checked in: anyone at the door could read it.
    return InsightCard(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(session: active, now: now, onOpenAdmin: onOpenAdmin),
          Expanded(
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween(begin: 0.96, end: 1.0).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(event ?? active?.id ?? 'idle'),
                // Scale the result down rather than clip it when the panel
                // is short.
                child: LayoutBuilder(
                  builder: (context, box) => FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(width: box.maxWidth, child: hero),
                  ),
                ),
              ),
            ),
          ),
          if (!hasSchedule || active != null)
            _PresentMeter(
              present: records.map((r) => r.studentId).toSet().length,
              // No "of N" without a class list or typed headcount.
              expected: active?.headcount(0) ?? 0,
            ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.session,
    required this.now,
    required this.onOpenAdmin,
  });

  final SessionEntry? session;
  final DateTime now;
  final VoidCallback onOpenAdmin;

  @override
  Widget build(BuildContext context) {
    final secondary = InsightColors.secondaryLabel.resolveFrom(context);
    final s = session;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s?.title ?? 'Check-in',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: InsightText.title2.copyWith(
                  color: InsightColors.label.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                s == null
                    ? formatLongDate(now)
                    : '${s.room.isEmpty ? '' : '${s.room} · '}${formatSessionRange(s)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: InsightText.subheadline.copyWith(color: secondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FillIconButton(
          icon: CupertinoIcons.lock_fill,
          semanticLabel: 'Admin',
          onPressed: onOpenAdmin,
        ),
      ],
    );
  }
}

/// The kiosk at rest: the time, large enough to read from the door, and
/// whether arriving now still counts as on time. The capsule over the
/// camera says what to do.
class _IdleView extends StatelessWidget {
  const _IdleView({required this.now, required this.session});

  final DateTime now;
  final SessionEntry? session;

  @override
  Widget build(BuildContext context) {
    final secondary = InsightColors.secondaryLabel.resolveFrom(context);
    final s = session;
    final cutoff = s == null ? null : s.startMinuteOfDay + s.lateAfterMinutes;
    final late = s != null && isLateFor(s, now);
    // "9:41 AM" as a lock-screen "9:41" with a small "AM".
    final clock = formatClock(now).split(' ');

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                clock.first,
                style: InsightText.largeTitle.copyWith(
                  fontSize: 76,
                  height: 1.1,
                  letterSpacing: -1.5,
                  color: InsightColors.label.resolveFrom(context),
                  fontFeatures: InsightText.tabular,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                clock.last,
                style: InsightText.title2.copyWith(color: secondary),
              ),
            ],
          ),
          if (cutoff != null) ...[
            const SizedBox(height: 10),
            Text(
              late
                  ? 'Check-ins now count as late'
                  : 'On time until ${formatMinuteOfDay(cutoff)}',
              textAlign: TextAlign.center,
              style: InsightText.title3.copyWith(
                color: late
                    ? InsightColors.warning.resolveFrom(context)
                    : secondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EventView extends StatelessWidget {
  const _EventView({required this.event, required this.session});

  final ScanEvent event;
  final SessionEntry? session;

  @override
  Widget build(BuildContext context) {
    final label = InsightColors.label.resolveFrom(context);
    final secondary = InsightColors.secondaryLabel.resolveFrom(context);

    final offList = event.kind == ScanEventKind.notOnClassList;
    if (event.kind == ScanEventKind.unknown || offList) {
      final warning = InsightColors.warning.resolveFrom(context);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              offList
                  ? CupertinoIcons.person_crop_circle_badge_exclam
                  : CupertinoIcons.person_crop_circle_badge_xmark,
              size: 96,
              color: warning,
            ),
            const SizedBox(height: 20),
            Text(
              offList ? 'Not on the Class List' : 'Face Not Recognized',
              textAlign: TextAlign.center,
              style: InsightText.largeTitle.copyWith(color: label),
            ),
            const SizedBox(height: 10),
            Text(
              offList
                  ? '${event.student?.name ?? 'You'} isn\'t listed for '
                        '${session?.title ?? 'this class'}. Please see your '
                        'instructor.'
                  : 'Step closer and look straight at the camera, or see your instructor.',
              textAlign: TextAlign.center,
              style: InsightText.title3.copyWith(
                color: secondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }

    final student = event.student;
    final record = event.attendance;
    final name = student?.name ?? record?.studentId ?? 'Student';
    final checkedIn = event.kind == ScanEventKind.checkedIn;
    final time = record?.timestamp ?? event.at ?? DateTime.now();

    final late = checkedIn && session != null && isLateFor(session!, time);

    // One color per outcome, on the badge and the status line alike.
    final (IconData icon, Color color, String status) = !checkedIn
        ? (
            CupertinoIcons.info_circle_fill,
            InsightColors.accent.resolveFrom(context),
            'Already checked in',
          )
        : late
        ? (
            CupertinoIcons.clock_fill,
            InsightColors.warning.resolveFrom(context),
            'Late',
          )
        : (
            CupertinoIcons.checkmark_circle_fill,
            InsightColors.success.resolveFrom(context),
            session == null ? 'Checked in' : 'On time',
          );

    // The full name, once and large: it confirms the right person was
    // recognized, which a first-name greeting can't.
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              InitialsAvatar(name: name, size: 132),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: InsightColors.card.resolveFrom(context),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Icon(icon, size: 42, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: InsightText.largeTitle.copyWith(color: label),
          ),
          const SizedBox(height: 10),
          Text(
            '$status · ${formatClock(time)}',
            textAlign: TextAlign.center,
            style: InsightText.title3.copyWith(
              color: color,
              fontFeatures: InsightText.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

class _PresentMeter extends StatelessWidget {
  const _PresentMeter({required this.present, required this.expected});

  final int present;
  final int expected;

  @override
  Widget build(BuildContext context) {
    final label = InsightColors.label.resolveFrom(context);
    final secondary = InsightColors.secondaryLabel.resolveFrom(context);
    final fraction = expected > 0 ? (present / expected).clamp(0.0, 1.0) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Present',
              style: InsightText.subheadline.copyWith(color: secondary),
            ),
            const Spacer(),
            Text(
              '$present',
              style: InsightText.title2.copyWith(
                color: label,
                fontFeatures: InsightText.tabular,
              ),
            ),
            if (expected > 0)
              Text(
                ' of $expected',
                style: InsightText.subheadline.copyWith(
                  color: secondary,
                  fontFeatures: InsightText.tabular,
                ),
              ),
          ],
        ),
        if (fraction != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(InsightRadii.capsule),
            child: SizedBox(
              height: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: InsightColors.fill.resolveFrom(context)),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: fraction,
                    child: ColoredBox(
                      color: InsightColors.success.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
