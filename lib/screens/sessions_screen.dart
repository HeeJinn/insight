import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app_theme.dart';
import '../widgets/app_chrome.dart';
import '../widgets/responsive_utils.dart';

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Sessions'),
      ),
      body: AppBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final contentWidth = AppBreakpoints.contentWidth(width);
            final padding = AppBreakpoints.pagePadding(width);
            final compact = AppBreakpoints.isCompact(width);

            return SafeArea(
              child: SingleChildScrollView(
                padding: padding,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppPanel(
                          child: AppSectionHeading(
                            eyebrow: 'Class sessions',
                            title: 'Today\'s Schedule',
                            subtitle:
                                'Prototype timetable for quick launch into kiosk and attendance scanning.',
                            compact: false,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ..._demoSessions.map(
                          (session) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SessionCard(
                              session: session,
                              compact: compact,
                            ),
                          ),
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
    );
  }
}

class _SessionCard extends StatelessWidget {
  final _Session session;
  final bool compact;

  const _SessionCard({required this.session, required this.compact});

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.schedule, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.course, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(session.room, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    AppPillTag(
                      label: session.time,
                      icon: Icons.access_time_rounded,
                      backgroundColor: AppTheme.orangeSoft,
                      foregroundColor: AppTheme.orange,
                    ),
                    AppPillTag(
                      label: '${session.expected} expected',
                      icon: Icons.groups_2_outlined,
                      backgroundColor: AppTheme.blueSoft,
                      foregroundColor: AppTheme.blue,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!compact)
            OutlinedButton.icon(
              onPressed: () => context.push('/kiosk'),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Start Kiosk'),
            ),
        ],
      ),
    );
  }
}

class _Session {
  final String course;
  final String room;
  final String time;
  final int expected;

  const _Session({
    required this.course,
    required this.room,
    required this.time,
    required this.expected,
  });
}

const _demoSessions = <_Session>[
  _Session(
    course: 'Software Engineering',
    room: 'Room B-201',
    time: '08:30 - 10:00',
    expected: 42,
  ),
  _Session(
    course: 'Computer Vision Lab',
    room: 'Lab A-07',
    time: '10:30 - 12:00',
    expected: 28,
  ),
  _Session(
    course: 'Data Structures',
    room: 'Room C-109',
    time: '13:00 - 14:30',
    expected: 51,
  ),
];
