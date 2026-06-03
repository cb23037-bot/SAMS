import 'activity_slot.dart';

/// Lightweight activity info embedded inside [ActivityRegistration].
///
/// This is a separate, smaller model from [Activity] because the registration
/// endpoint returns only the fields needed to display the student's curriculum
/// page — it does not include the full slot list that [Activity] carries.
class RegistrationActivity {
  const RegistrationActivity({
    required this.id,
    required this.name,
    required this.code,
    required this.cats,
    this.whatsappLink,
    this.description,
  });

  /// Database primary key of the activity.
  final int id;

  /// Full name of the activity.
  final String name;

  /// Short activity code (e.g. "GRK2024").
  final String code;

  /// Number of CATs (Co-Curriculum Activity Transcript) credits this
  /// activity awards upon successful claim. Defaults to 2 if not set.
  final int cats;

  /// Optional WhatsApp group link for the activity.
  final String? whatsappLink;

  /// Optional description of the activity.
  final String? description;

  // ── Factory constructor ────────────────────────────────────────────────────

  /// Deserializes from JSON. [cats] defaults to 2 if the backend omits it,
  /// matching the database default value.
  factory RegistrationActivity.fromJson(Map<String, dynamic> json) {
    return RegistrationActivity(
      id:           (json['id'] as num).toInt(),
      name:         json['name'] as String,
      code:         json['code'] as String,
      cats:         (json['cats'] as num?)?.toInt() ?? 2,
      whatsappLink: json['whatsapp_link'] as String?,
      description:  json['description'] as String?,
    );
  }
}

/// Represents a student's registration record for one activity slot.
///
/// This model serves dual purpose — it tracks both the slot registration
/// and the credit claim lifecycle for that registration. The [claimStatus]
/// field progresses through states as the student submits and Pusat Adab
/// reviews the claim:
///
///   not_claimed → pending → claimed
///                         → rejected → (student re-submits) → pending
class ActivityRegistration {
  const ActivityRegistration({
    required this.id,
    required this.claimStatus,
    required this.hasProof,
    required this.activity,
    required this.slot,
    this.updatedAt,
  });

  /// Database primary key of the registration record.
  final int id;

  /// Current state of the credit claim for this registration.
  /// Possible values: 'not_claimed' | 'pending' | 'claimed' | 'rejected'
  final String claimStatus;

  /// True if the student has uploaded a proof document for this claim.
  /// Used to show/hide the "View Proof" button on the curriculum page.
  final bool hasProof;

  /// The activity this registration belongs to.
  final RegistrationActivity activity;

  /// The specific slot the student registered for.
  final ActivitySlot slot;

  /// ISO 8601 timestamp of the last status change (e.g. when claim was submitted).
  /// Used by the notification page to determine if a notification is "new".
  final String? updatedAt;

  // ── Status helpers ─────────────────────────────────────────────────────────

  /// True if the student has not yet submitted a credit claim.
  bool get isNotClaimed => claimStatus == 'not_claimed';

  /// True if the claim has been submitted and is waiting for Pusat Adab review.
  bool get isPending    => claimStatus == 'pending';

  /// True if Pusat Adab has approved the credit claim.
  bool get isClaimed    => claimStatus == 'claimed';

  /// True if Pusat Adab has rejected the credit claim.
  bool get isRejected   => claimStatus == 'rejected';

  // ── copyWith ───────────────────────────────────────────────────────────────

  /// Returns a new registration with updated [claimStatus] or [hasProof].
  /// Used to update the local list after an API action (e.g. submitting a claim)
  /// without re-fetching the entire list from the server.
  ActivityRegistration copyWith({String? claimStatus, bool? hasProof}) {
    return ActivityRegistration(
      id:          id,
      claimStatus: claimStatus ?? this.claimStatus,
      hasProof:    hasProof ?? this.hasProof,
      activity:    activity,
      slot:        slot,
      updatedAt:   updatedAt,
    );
  }

  // ── Factory constructor ────────────────────────────────────────────────────

  /// Deserializes from the JSON returned by the student registrations endpoint.
  factory ActivityRegistration.fromJson(Map<String, dynamic> json) {
    return ActivityRegistration(
      id:          (json['id'] as num).toInt(),
      claimStatus: json['claim_status'] as String,
      hasProof:    (json['has_proof'] as bool?) ?? false,
      activity:    RegistrationActivity.fromJson(json['activity'] as Map<String, dynamic>),
      slot:        ActivitySlot.fromJson(json['slot'] as Map<String, dynamic>),
      updatedAt:   json['updated_at'] as String?,
    );
  }
}
