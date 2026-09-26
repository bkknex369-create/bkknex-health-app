import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

/// Denylist-based scrubbing applied to every event before it leaves the
/// device. Health values, message text, and transcripts must never reach
/// Sentry — this is a hard privacy gate.
const _sensitiveKeys = {
  'value',
  'message',
  'text',
  'transcript',
  'notes',
  'description',
  'calories',
  'weight_kg',
  'hours_slept',
  'amount_ml',
};

FutureOr<SentryEvent?> scrubBeforeSend(SentryEvent event, Hint hint) {
  final scrubbedExtra = event.extra == null
      ? null
      : {
          for (final entry in event.extra!.entries)
            if (!_sensitiveKeys.contains(entry.key.toLowerCase()))
              entry.key: entry.value,
        };
  final scrubbedBreadcrumbs = event.breadcrumbs
      ?.map((b) => b.copyWith(
            data: b.data == null
                ? null
                : {
                    for (final entry in b.data!.entries)
                      if (!_sensitiveKeys.contains(entry.key.toLowerCase()))
                        entry.key: entry.value,
                  },
          ))
      .toList();
  return event.copyWith(extra: scrubbedExtra, breadcrumbs: scrubbedBreadcrumbs);
}
