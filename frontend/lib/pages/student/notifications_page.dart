import 'package:flutter/material.dart';

import '../../app/app_controller.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const _blue = Color(0xFF1565C0);
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.controller.apiService.getNotifications(
        token: widget.controller.token!,
      );
      setState(() {
        _notifications = (data['notifications'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    try {
      await widget.controller.apiService.markAllNotificationsRead(
        token: widget.controller.token!,
      );
      setState(() {
        _notifications = _notifications
            .map((n) => {...n, 'is_read': true})
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _markRead(int id) async {
    try {
      await widget.controller.apiService.markNotificationRead(
        token: widget.controller.token!,
        id: id,
      );
      setState(() {
        _notifications = _notifications.map((n) {
          if (n['id'] == id) return {...n, 'is_read': true};
          return n;
        }).toList();
      });
    } catch (_) {}
  }

  int get _unreadCount =>
      _notifications.where((n) => n['is_read'] == false).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: _blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Notifications',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _blue,
                  child: _notifications.isEmpty ? _buildEmpty() : _buildList(),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined, size: 52, color: Color(0xFFD1D5DB)),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _blue),
            onPressed: _load,
            child: const Text('Retry'),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(children: const [
      SizedBox(height: 120),
      Icon(Icons.notifications_none_rounded, size: 56, color: Color(0xFFD1D5DB)),
      SizedBox(height: 12),
      Text('No notifications yet.',
          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
          textAlign: TextAlign.center),
    ]);
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      itemCount: _notifications.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final n       = _notifications[i];
        final isRead  = n['is_read'] == true;
        final type    = n['type'] as String? ?? '';
        final id      = n['id'] as int;

        final (icon, iconBg, iconFg) = switch (type) {
          'payment_success'  => (Icons.check_circle_rounded,  const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
          'restriction'      => (Icons.warning_rounded,       const Color(0xFFFFEBEE), const Color(0xFFDC2626)),
          'access_restored'  => (Icons.lock_open_rounded,     const Color(0xFFEFF6FF), const Color(0xFF1565C0)),
          _                  => (Icons.notifications_rounded, const Color(0xFFF3F4F6), const Color(0xFF6B7280)),
        };

        final timeAgo = _timeAgo(n['created_at'] as String? ?? '');

        return GestureDetector(
          onTap: isRead ? null : () => _markRead(id),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: isRead
                  ? null
                  : const Border(left: BorderSide(color: Color(0xFF1565C0), width: 3)),
              boxShadow: const [
                BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                  child: Icon(icon, color: iconFg, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text(n['title'] as String? ?? '',
                            style: TextStyle(
                                fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                fontSize: 14,
                                color: const Color(0xFF111827))),
                      ),
                      if (!isRead)
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                              color: Color(0xFF1565C0), shape: BoxShape.circle),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    Text(n['message'] as String? ?? '',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(timeAgo,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                  ]),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  String _timeAgo(String iso) {
    try {
      final dt   = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1)  return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)   return '${diff.inHours}h ago';
      if (diff.inDays < 7)     return '${diff.inDays}d ago';
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) { return ''; }
  }
}
