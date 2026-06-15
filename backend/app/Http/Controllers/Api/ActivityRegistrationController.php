<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Api\AccessController;
use App\Models\ActivityRegistration;
use App\Models\ActivitySlot;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class ActivityRegistrationController extends Controller
{
    private static function registrationArray(ActivityRegistration $reg): array
    {
        $slot     = $reg->slot;
        $activity = $slot->activity;

        return [
            'id'               => $reg->id,
            'claim_status'     => $reg->claim_status,
            'has_proof'        => !is_null($reg->proof_path),
            'rejection_reason' => $reg->rejection_reason,
            'updated_at'       => $reg->updated_at?->toISOString(),
            'activity'     => [
                'id'            => $activity->id,
                'name'          => $activity->name,
                'code'          => $activity->code,
                'cats'          => $activity->cats ?? 2,
                'whatsapp_link' => $activity->whatsapp_link,
                'description'   => $activity->description,
            ],
            'slot'         => [
                'id'          => $slot->id,
                'activity_id' => $slot->activity_id,
                'date'        => $slot->date->format('Y-m-d'),
                'time'        => $slot->time,
                'capacity'    => $slot->capacity,
                'registered'  => $slot->registered,
            ],
        ];
    }

    // GET /api/student/registrations
    public function index(Request $request): JsonResponse
    {
        $this->requireStudent($request);

        $registrations = ActivityRegistration::with(['slot.activity'])
            ->where('user_id', $request->user()->id)
            ->latest()
            ->get();

        return response()->json([
            'registrations' => $registrations->map(fn($r) => self::registrationArray($r))->values(),
        ]);
    }

    // POST /api/student/registrations  { slot_id }
    public function store(Request $request): JsonResponse
    {
        $this->requireStudent($request);

        if (AccessController::accessState()['student_access'] === 'closed') {
            return response()->json(['message' => 'Activity registration is closed after Week 5 or by administrator control.'], 403);
        }

        $validated = $request->validate([
            'slot_id' => ['required', 'integer', 'exists:activity_slots,id'],
        ]);

        $slot = ActivitySlot::with('activity')->findOrFail($validated['slot_id']);

        // Prevent duplicate registration for same activity (any slot)
        $alreadyRegistered = ActivityRegistration::whereHas('slot', function ($q) use ($slot) {
            $q->where('activity_id', $slot->activity_id);
        })->where('user_id', $request->user()->id)->exists();

        if ($alreadyRegistered) {
            return response()->json(['message' => 'You are already registered for this activity.'], 422);
        }

        if ($slot->registered >= $slot->capacity) {
            return response()->json(['message' => 'This slot is full.'], 422);
        }

        $registration = ActivityRegistration::create([
            'user_id'          => $request->user()->id,
            'activity_slot_id' => $slot->id,
            'claim_status'     => 'not_claimed',
        ]);

        $slot->increment('registered');
        $registration->load('slot.activity');

        return response()->json([
            'registration' => self::registrationArray($registration),
        ], 201);
    }

    // DELETE /api/student/registrations/{registration}  (only if not_claimed)
    public function destroy(Request $request, ActivityRegistration $registration): JsonResponse
    {
        $this->requireStudent($request);

        if ($registration->user_id !== $request->user()->id) {
            abort(403, 'Unauthorized.');
        }

        if ($registration->claim_status !== 'not_claimed') {
            return response()->json(['message' => 'Cannot cancel a claimed or pending registration.'], 422);
        }

        $registration->slot->decrement('registered');
        $registration->delete();

        return response()->json(['status' => 'success', 'message' => 'Registration cancelled.']);
    }

    // POST /api/student/registrations/{registration}/claim  — requires proof file upload
    public function claim(Request $request, ActivityRegistration $registration): JsonResponse
    {
        $this->requireStudent($request);

        if (AccessController::accessState()['student_access'] === 'closed') {
            return response()->json(['message' => 'Credit claim submission is closed after Week 5 or by administrator control.'], 403);
        }

        if ($registration->user_id !== $request->user()->id) {
            abort(403, 'Unauthorized.');
        }

        if ($registration->claim_status !== 'not_claimed') {
            return response()->json(['message' => 'Already claimed or pending.'], 422);
        }

        $request->validate([
            'proof' => ['required', 'file', 'mimes:pdf', 'max:5120'],
        ]);

        // Delete old proof if any (shouldn't exist, but just in case)
        if ($registration->proof_path) {
            Storage::disk('public')->delete($registration->proof_path);
        }

        $path = $request->file('proof')->store('proofs', 'public');

        $registration->update([
            'claim_status' => 'pending',
            'proof_path'   => $path,
        ]);

        $registration->load('slot.activity');

        return response()->json(['registration' => self::registrationArray($registration)]);
    }

    // DELETE /api/student/registrations/{registration}/claim  (pending → not_claimed)
    public function cancelClaim(Request $request, ActivityRegistration $registration): JsonResponse
    {
        $this->requireStudent($request);

        if ($registration->user_id !== $request->user()->id) {
            abort(403, 'Unauthorized.');
        }

        if ($registration->claim_status !== 'pending') {
            return response()->json(['message' => 'No pending claim to cancel.'], 422);
        }

        // Remove proof file when cancelling claim
        if ($registration->proof_path) {
            Storage::disk('public')->delete($registration->proof_path);
        }

        $registration->update([
            'claim_status' => 'not_claimed',
            'proof_path'   => null,
        ]);

        $registration->load('slot.activity');

        return response()->json(['registration' => self::registrationArray($registration)]);
    }
}
