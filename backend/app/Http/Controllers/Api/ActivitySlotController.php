<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Activity;
use App\Models\ActivitySlot;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ActivitySlotController extends Controller
{
    public function store(Request $request, Activity $activity): JsonResponse
    {
        $this->requireAdab($request);

        $validated = $request->validate([
            'date'     => ['required', 'date'],
            'time'     => ['required', 'string', 'max:50'],
            'capacity' => ['required', 'integer', 'min:1'],
        ]);

        $slot = $activity->slots()->create(array_merge($validated, [
            'registered'      => 0,
            'attendance_code' => $this->generateAttendanceCode(),
        ]));

        return response()->json([
            'status' => 'success',
            'slot'   => self::slotArray($slot),
        ], 201);
    }

    public function update(Request $request, Activity $activity, ActivitySlot $slot): JsonResponse
    {
        $this->requireAdab($request);

        if ($slot->activity_id !== $activity->id) {
            return response()->json(['status' => 'error', 'message' => 'Slot not found.'], 404);
        }

        $validated = $request->validate([
            'date'     => ['required', 'date'],
            'time'     => ['required', 'string', 'max:50'],
            'capacity' => ['required', 'integer', 'min:1'],
        ]);

        if ($validated['capacity'] < $slot->registered) {
            return response()->json([
                'status'  => 'error',
                'message' => "Capacity cannot be less than the {$slot->registered} student(s) already registered.",
            ], 422);
        }

        $slot->update($validated);

        return response()->json([
            'status' => 'success',
            'slot'   => self::slotArray($slot),
        ]);
    }

    public function destroy(Request $request, Activity $activity, ActivitySlot $slot): JsonResponse
    {
        $this->requireAdab($request);

        if ($slot->activity_id !== $activity->id) {
            return response()->json(['status' => 'error', 'message' => 'Slot not found.'], 404);
        }

        $slot->delete();

        return response()->json(['status' => 'success', 'message' => 'Slot deleted.']);
    }

    public static function slotArray(ActivitySlot $slot): array
    {
        return [
            'id'              => $slot->id,
            'activity_id'     => $slot->activity_id,
            'date'            => $slot->date->format('Y-m-d'),
            'time'            => $slot->time,
            'capacity'        => $slot->capacity,
            'registered'      => $slot->registered,
            'attendance_code' => $slot->attendance_code,
        ];
    }

    private function generateAttendanceCode(): string
    {
        // 6-char alphanumeric, excludes ambiguous chars (0,1,I,O)
        $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        do {
            $code = '';
            for ($i = 0; $i < 6; $i++) {
                $code .= $chars[random_int(0, strlen($chars) - 1)];
            }
        } while (ActivitySlot::where('attendance_code', $code)->exists());

        return $code;
    }
}
