<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ActivityRegistration;
use App\Models\ActivitySlot;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

/**
 * Mengurus pendaftaran pelajar ke slot aktiviti dan aliran tuntutan kredit.
 *
 * Kitaran hayat claim_status:
 *   not_claimed → (claim) → pending → (approve) → claimed
 *                                    → (reject)  → rejected
 *                         → (cancelClaim) → not_claimed
 */
class ActivityRegistrationController extends Controller
{
    /**
     * Tukar model ActivityRegistration kepada array JSON ringkas untuk frontend.
     * Hanya hantar 'has_proof' (boolean) bukan path sebenar — path hanya
     * dihantar melalui CreditClaimController untuk tujuan keselamatan.
     */
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
    // Kembalikan semua pendaftaran aktiviti milik pelajar yang sedang log masuk.
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
    // Semak akses, pendaftaran berganda, dan kapasiti sebelum buat rekod.
    public function store(Request $request): JsonResponse
    {
        $this->requireStudent($request);

        // Halang pendaftaran jika Pusat Adab telah menutup akses sistem
        if ((DB::table('settings')->where('key', 'student_access')->value('value') ?? 'open') === 'closed') {
            return response()->json(['message' => 'Activity registration is currently closed. Please try again later.'], 403);
        }

        $validated = $request->validate([
            'slot_id' => ['required', 'integer', 'exists:activity_slots,id'],
        ]);

        $slot = ActivitySlot::with('activity')->findOrFail($validated['slot_id']);

        // Prevent duplicate registration for same activity (any slot)
        // Semak merentasi semua slot untuk aktiviti yang sama, bukan slot ini sahaja
        $alreadyRegistered = ActivityRegistration::whereHas('slot', function ($q) use ($slot) {
            $q->where('activity_id', $slot->activity_id);
        })->where('user_id', $request->user()->id)->exists();

        if ($alreadyRegistered) {
            return response()->json(['message' => 'You are already registered for this activity.'], 422);
        }

        // Semak slot penuh sebelum buat rekod pendaftaran
        if ($slot->registered >= $slot->capacity) {
            return response()->json(['message' => 'This slot is full.'], 422);
        }

        $registration = ActivityRegistration::create([
            'user_id'          => $request->user()->id,
            'activity_slot_id' => $slot->id,
            'claim_status'     => 'not_claimed',
        ]);

        // Tambah kiraan registered pada slot selepas pendaftaran berjaya
        $slot->increment('registered');
        $registration->load('slot.activity');

        return response()->json([
            'registration' => self::registrationArray($registration),
        ], 201);
    }

    // DELETE /api/student/registrations/{registration}  (only if not_claimed)
    // Hanya boleh batal jika belum submit tuntutan (status = not_claimed).
    public function destroy(Request $request, ActivityRegistration $registration): JsonResponse
    {
        $this->requireStudent($request);

        if ($registration->user_id !== $request->user()->id) {
            abort(403, 'Unauthorized.');
        }

        if ($registration->claim_status !== 'not_claimed') {
            return response()->json(['message' => 'Cannot cancel a claimed or pending registration.'], 422);
        }

        // Kurangkan kiraan registered pada slot apabila pendaftaran dibatal
        $registration->slot->decrement('registered');
        $registration->delete();

        return response()->json(['status' => 'success', 'message' => 'Registration cancelled.']);
    }

    // POST /api/student/registrations/{registration}/claim  — requires proof file upload
    // Pelajar muat naik resit PDF sebagai bukti kehadiran; status bertukar ke 'pending'.
    public function claim(Request $request, ActivityRegistration $registration): JsonResponse
    {
        $this->requireStudent($request);

        // Halang submission jika Pusat Adab telah menutup akses sistem
        if ((DB::table('settings')->where('key', 'student_access')->value('value') ?? 'open') === 'closed') {
            return response()->json(['message' => 'Credit claim submission is currently closed. Please try again later.'], 403);
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

        // Simpan fail PDF bukti di storage/app/public/proofs/
        $path = $request->file('proof')->store('proofs', 'public');

        $registration->update([
            'claim_status' => 'pending',
            'proof_path'   => $path,
        ]);

        $registration->load('slot.activity');

        return response()->json(['registration' => self::registrationArray($registration)]);
    }

    // DELETE /api/student/registrations/{registration}/claim  (pending → not_claimed)
    // Pelajar tarik balik tuntutan yang masih pending; fail bukti dipadam dari storage.
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
