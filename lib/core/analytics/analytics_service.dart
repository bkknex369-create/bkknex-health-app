import 'package:posthog_flutter/posthog_flutter.dart';
import 'analytics_events.dart';

/// Thin wrapper so every call site goes through the allow-listed
/// [AnalyticsEvent] enum. Properties must never contain raw health values,
/// message text, or transcripts — this is a hard privacy gate, not a style
/// preference, so only pass small categorical properties here.
class AnalyticsService {
  const AnalyticsService();

  Future<void> capture(
    AnalyticsEvent event, {
    Map<String, Object>? properties,
  }) {
    return Posthog().capture(
      eventName: event.eventName,
      properties: properties,
    );
  }
}
