class UnifiedNotification {
  final String id;
  final String title;
  final String message;
  final String type; // 'activity' or 'fees'
  final bool isRead;
  final DateTime createdAt;
  final String? status; // for activity: 'claimed', 'pending', 'rejected'

  const UnifiedNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.status,
  });
}
