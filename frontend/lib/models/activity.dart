import 'activity_slot.dart';

/// Represents a KoQ (Ko-Kurikulum) curriculum activity managed by Pusat Adab.
///
/// Each activity has multiple [slots] (specific dates and times).
/// Students register for one slot per activity to earn CATs credit.
/// This model is used by both the student KoQ booking page and the
/// Pusat Adab manage activities page.
class Activity {
  const Activity({
    required this.id,
    required this.name,
    required this.code,
    this.whatsappLink,
    this.description,
    this.location,
    required this.slots,
  });

  /// Database primary key.
  final int id;

  /// Full name of the activity (e.g. "Gotong Royong Kampus").
  final String name;

  /// Short unique code used for quick identification (e.g. "GRK2024").
  final String code;

  /// Optional WhatsApp group link for activity announcements.
  final String? whatsappLink;

  /// Optional description explaining the activity's purpose or requirements.
  final String? description;

  /// Venue or location where the activity takes place.
  final String? location;

  /// All date/time slots available for this activity.
  /// Students choose one slot when registering.
  final List<ActivitySlot> slots;

  // ── Computed properties ────────────────────────────────────────────────────

  /// Total number of seats across all slots combined.
  /// Used on the booking card to show overall capacity.
  int get totalCapacity => slots.fold<int>(0, (sum, s) => sum + s.capacity);

  /// Number of slots that still have remaining capacity.
  /// Used to determine if there are any slots worth showing to the student.
  int get availableSlotsCount => slots.where((s) => s.registered < s.capacity).length;

  // ── copyWith ───────────────────────────────────────────────────────────────

  /// Returns a copy of this activity with updated [slots].
  /// Only slots can be updated here because activities themselves are
  /// refreshed from the server when slots are added or removed.
  Activity copyWith({List<ActivitySlot>? slots}) {
    return Activity(
      id:           id,
      name:         name,
      code:         code,
      whatsappLink: whatsappLink,
      description:  description,
      location:     location,
      slots:        slots ?? this.slots,
    );
  }

  // ── Factory constructor ────────────────────────────────────────────────────

  /// Deserializes an [Activity] from the JSON response.
  /// The nested 'slots' array is mapped into a list of [ActivitySlot] objects.
  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id:           (json['id'] as num).toInt(),
      name:         json['name'] as String,
      code:         json['code'] as String,
      whatsappLink: json['whatsapp_link'] as String?,
      description:  json['description'] as String?,
      location:     json['location'] as String?,
      slots: (json['slots'] as List<dynamic>)
          .map((s) => ActivitySlot.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}
