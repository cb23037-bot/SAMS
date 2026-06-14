<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
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

    public function markRead(Request $request, Notification $notification): JsonResponse
    {
        if ($notification->user_id !== $request->user()->id) {
            abort(403);
        }
        $notification->update(['is_read' => true]);
        return response()->json(['message' => 'Marked as read.']);
    }

    public function markAllRead(Request $request): JsonResponse
    {
        Notification::where('user_id', $request->user()->id)
            ->where('is_read', false)
            ->update(['is_read' => true]);
        return response()->json(['message' => 'All notifications marked as read.']);
    }

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
