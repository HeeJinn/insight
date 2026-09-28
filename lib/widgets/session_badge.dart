import 'package:flutter/cupertino.dart';

import '../models/session_entry.dart';
import '../services/session_clock.dart';
import '../ui/insight_ui.dart';

/// A session's state today as a leading badge: done (gray check), running
/// (green), or upcoming (blue clock).
class SessionStateBadge extends StatelessWidget {
  const SessionStateBadge({
    super.key,
    required this.session,
    required this.now,
  });

  final SessionEntry session;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final minute = minuteOfDay(now);
    final today = session.occursOn(now);
    if (today && minute > session.endMinuteOfDay) {
      return SymbolBadge(
        CupertinoIcons.checkmark_alt,
        CupertinoColors.systemGrey.resolveFrom(context),
      );
    }
    if (today && minute >= session.startMinuteOfDay) {
      return SymbolBadge(
        CupertinoIcons.dot_radiowaves_left_right,
        InsightColors.success.resolveFrom(context),
      );
    }
    return SymbolBadge(
      session.isOneOff ? CupertinoIcons.calendar : CupertinoIcons.clock_fill,
      session.isOneOff
          ? CupertinoColors.systemIndigo.resolveFrom(context)
          : InsightColors.accent.resolveFrom(context),
    );
  }
}
