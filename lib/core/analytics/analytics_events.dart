/// Allow-listed PostHog event names (source plan §23). Compile-time
/// constants only — call sites reference [AnalyticsEvent] values, so a
/// stray/free-form event name is a compile error, not a silent privacy
/// leak.
///
/// KNOWN LIMITATION: this pass could not re-fetch the literal §23 text from
/// BKK-76 (doc/API access was unavailable — see the BKK-78 status comment).
/// The names below are structurally correct placeholders covering this
/// task's Phase 0/1 flows; confirm each one against the real §23 list
/// before wiring any new call site, and rename here (single source of
/// truth) if any differ.
enum AnalyticsEvent {
  onboardingCompleted('onboarding_completed'),
  homeViewed('home_viewed'),
  wellnessScoreViewed('wellness_score_viewed'),
  quickActionLogged('quick_action_logged'),
  metricLogged('metric_logged'),
  seniorModeToggled('senior_mode_toggled');

  const AnalyticsEvent(this.eventName);

  final String eventName;
}
