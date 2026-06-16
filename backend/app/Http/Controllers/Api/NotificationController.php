<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    // GET /api/notifications
    // Returns all notifications for the authenticated user, ordered newest-first,
    // along with the total count of unread notifications.
    // On any database error, returns an empty list and zero unread count instead
    // of propagating an error — keeps the frontend from breaking if notifications fail.
    public function index(Request $request): JsonResponse
    {
        try {
            $notifications = Notification::where('user_id', $request->user()->id)
                ->orderByDesc('created_at')
                ->get();

            return response()->json([
                'notifications' => $notifications->map(fn($n) => $this->notifArray($n)),
                'unread_count'  => $notifications->where('is_read', false)->count(),
            ]);
        } catch (\Exception $e) {
            return response()->json(['notifications' => [], 'unread_count' => 0]);
        }
    }

    // GET /api/notifications/unread-count
    // Returns only the count of unread notifications for the authenticated user.
    // Used by the app shell to display the badge on the notification icon
    // without fetching the full notification list.
    public function unreadCount(Request $request): JsonResponse
    {
        try {
            $count = Notification::where('user_id', $request->user()->id)
                ->where('is_read', false)
                ->count();
            return response()->json(['unread_count' => $count]);
        } catch (\Exception $e) {
            return response()->json(['unread_count' => 0]);
        }
    }

    // PATCH /api/notifications/{notification}/read
    // Marks a single notification as read. Returns 403 if the notification
    // does not belong to the authenticated user.
    public function markRead(Request $request, Notification $notification): JsonResponse
    {
        if ($notification->user_id !== $request->user()->id) {
            abort(403);
        }
        $notification->update(['is_read' => true]);
        return response()->json(['message' => 'Marked as read.']);
    }

    // POST /api/notifications/mark-all-read
    // Marks every unread notification belonging to the authenticated user as read.
    // Performs a bulk update in one query rather than loading each record individually.
    public function markAllRead(Request $request): JsonResponse
    {
        Notification::where('user_id', $request->user()->id)
            ->where('is_read', false)
            ->update(['is_read' => true]);
        return response()->json(['message' => 'All notifications marked as read.']);
    }

    // Converts a Notification model into a flat array safe to return as JSON.
    // The 'type' field indicates what triggered the notification
    // (e.g. 'restriction', 'access_restored', 'payment_success').
    private function notifArray(Notification $n): array
    {
        return [
            'id'         => $n->id,
            'title'      => $n->title,
            'message'    => $n->message,
            'type'       => $n->type,
            'is_read'    => $n->is_read,
            'created_at' => $n->created_at->toISOString(),
        ];
    }
}
