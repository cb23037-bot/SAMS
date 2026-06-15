<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Activity;
use App\Models\ActivityRegistration;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class CreditClaimController extends Controller
{
    private static function claimArray(ActivityRegistration $reg): array
    {
        $slot     = $reg->slot;
        $activity = $slot->activity;
        $student  = $reg->user;

        return [
            'id'               => $reg->id,
            'claim_status'     => $reg->claim_status,
            'proof_path'       => $reg->proof_path,
            'remarks'          => $reg->remarks,
            'rejection_reason' => $reg->rejection_reason,
            'student'          => [
                'id'         => $student->id,
                'name'       => $student->name,
                'student_id' => $student->student_id,
                'course'     => $student->course,
                'email'      => $student->email,
            ],
            'activity'         => [
                'id'       => $activity->id,
                'name'     => $activity->name,
                'code'     => $activity->code,
                'location' => $activity->location,
                'cats'     => $activity->cats ?? 2,
            ],
            'slot'         => [
                'id'   => $slot->id,
                'date' => $slot->date->format('Y-m-d'),
                'time' => $slot->time,
            ],
            'submitted_at' => $reg->updated_at?->toISOString(),
        ];
    }

    // GET /api/adab/claims
    public function index(Request $request): JsonResponse
    {
        $this->requireAdab($request);

        $total            = ActivityRegistration::where('claim_status', '!=', 'not_claimed')->count();
        $pending          = ActivityRegistration::where('claim_status', 'pending')->count();
        $approved         = ActivityRegistration::where('claim_status', 'claimed')->count();
        $rejected         = ActivityRegistration::where('claim_status', 'rejected')->count();
        $activitiesTotal  = Activity::count();

        $activities = Activity::with(['slots.registrations' => function ($q) {
            $q->where('claim_status', '!=', 'not_claimed');
        }])->get();

        $activityList = $activities->map(function ($activity) {
            $regs = $activity->slots->flatMap(fn ($s) => $s->registrations);
            return [
                'id'              => $activity->id,
                'name'            => $activity->name,
                'code'            => $activity->code,
                'location'        => $activity->location,
                'claims_total'    => $regs->count(),
                'claims_pending'  => $regs->where('claim_status', 'pending')->count(),
                'claims_approved' => $regs->where('claim_status', 'claimed')->count(),
                'claims_rejected' => $regs->where('claim_status', 'rejected')->count(),
            ];
        })->filter(fn ($a) => $a['claims_total'] > 0)->values();

        return response()->json([
            'stats'      => compact('total', 'pending', 'approved', 'rejected', 'activitiesTotal'),
            'activities' => $activityList,
        ]);
    }

    // GET /api/adab/claims/{activityId}
    public function activityClaims(Request $request, int $activityId): JsonResponse
    {
        $this->requireAdab($request);

        $activity = Activity::findOrFail($activityId);

        $regs = ActivityRegistration::with(['slot.activity', 'user'])
            ->whereHas('slot', fn ($q) => $q->where('activity_id', $activityId))
            ->where('claim_status', '!=', 'not_claimed')
            ->latest()
            ->get();

        return response()->json([
            'activity' => [
                'id'       => $activity->id,
                'name'     => $activity->name,
                'code'     => $activity->code,
                'location' => $activity->location,
            ],
            'claims'   => $regs->map(fn ($r) => self::claimArray($r))->values(),
        ]);
    }

    // PUT /api/adab/claims/{registration}/approve
    public function approve(Request $request, ActivityRegistration $registration): JsonResponse
    {
        $this->requireAdab($request);

        if ($registration->claim_status !== 'pending') {
            return response()->json(['message' => 'Only pending claims can be approved.'], 422);
        }

        $request->validate([
            'remarks' => ['nullable', 'string', 'max:1000'],
        ]);

        $registration->update([
            'claim_status' => 'claimed',
            'remarks'      => $request->remarks,
        ]);

        $registration->load('slot.activity', 'user');

        return response()->json([
            'status' => 'success',
            'claim'  => self::claimArray($registration),
        ]);
    }

    // PUT /api/adab/claims/{registration}/reject
    public function reject(Request $request, ActivityRegistration $registration): JsonResponse
    {
        $this->requireAdab($request);

        if ($registration->claim_status !== 'pending') {
            return response()->json(['message' => 'Only pending claims can be rejected.'], 422);
        }

        $request->validate([
            'reason' => ['required', 'string', 'max:1000'],
        ]);

        $registration->update([
            'claim_status'     => 'rejected',
            'rejection_reason' => $request->reason,
        ]);

        $registration->load('slot.activity', 'user');

        return response()->json([
            'status' => 'success',
            'claim'  => self::claimArray($registration),
        ]);
    }

    // GET /api/adab/claims/{registration}/proof
    public function downloadProof(int $id)
    {
        $this->requireAdab(request());

        $registration = ActivityRegistration::findOrFail($id);

        if (!$registration->proof_path || !Storage::disk('public')->exists($registration->proof_path)) {
            return response()->json(['message' => 'Proof document not found.'], 404);
        }

        return Storage::disk('public')->download($registration->proof_path);
    }

    // GET /api/adab/notifications
    public function notifications(Request $request): JsonResponse
    {
        $this->requireAdab($request);

        $pending = ActivityRegistration::with(['slot.activity', 'user'])
            ->where('claim_status', 'pending')
            ->latest('updated_at')
            ->get();

        return response()->json([
            'pending_count' => $pending->count(),
            'claims'        => $pending->map(fn ($r) => self::claimArray($r))->values(),
        ]);
    }
}
