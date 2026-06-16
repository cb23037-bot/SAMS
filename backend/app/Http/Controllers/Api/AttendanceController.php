<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ActivitySlot;
use App\Models\AttendanceSubmission;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Menerima dan menyimpan rekod kehadiran pelajar untuk aktiviti kurikulum.
 *
 * Pelajar menghantar: kod kehadiran slot, foto selfie, dan koordinat GPS.
 * Sistem mengesahkan kod, menyimpan foto, lalu menjana ID resit + hash
 * untuk kegunaan muat turun resit PDF di frontend.
 */
class AttendanceController extends Controller
{
    // POST /api/attendance
    // Terima submission kehadiran pelajar — kod kehadiran wajib betul.
    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'slot_id'         => ['required', 'integer', 'exists:activity_slots,id'],
            'attendance_code' => ['required', 'string'],
            'photo'           => ['required', 'file', 'mimes:jpg,jpeg,png', 'max:10240'],
            'latitude'        => ['nullable', 'numeric'],
            'longitude'       => ['nullable', 'numeric'],
            'address'         => ['nullable', 'string', 'max:500'],
        ]);

        $slot = ActivitySlot::with('activity')->findOrFail($request->slot_id);

        // Sahkan kod kehadiran — case-insensitive, trim whitespace
        if (strtoupper(trim($request->attendance_code)) !== $slot->attendance_code) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Invalid attendance code. Please check with the event facilitator.',
            ], 422);
        }

        // Simpan foto selfie di storage/app/public/attendance_photos/
        $photoPath = $request->file('photo')->store('attendance_photos', 'public');

        // Jana ID resit yang boleh dibaca (contoh: RCP-MHW110-250616-1430)
        // dan hash SHA-256 untuk pengesahan integriti resit
        $receiptId   = $this->generateReceiptId($slot->activity->code);
        $receiptHash = hash('sha256', $receiptId . ':' . config('app.key'));

        $submission = AttendanceSubmission::create([
            'user_id'                  => $request->user()->id,
            'activity_slot_id'         => $slot->id,
            'attendance_code_submitted' => strtoupper(trim($request->attendance_code)),
            'photo_path'               => $photoPath,
            'latitude'                 => $request->latitude,
            'longitude'                => $request->longitude,
            'address'                  => $request->address,
            'receipt_id'               => $receiptId,
            'receipt_hash'             => $receiptHash,
        ]);

        return response()->json([
            'status'     => 'success',
            'submission' => [
                'id'           => $submission->id,
                'receipt_id'   => $receiptId,
                'receipt_hash' => $receiptHash,
            ],
        ], 201);
    }

    /**
     * Jana ID resit unik dalam format: RCP-{KOD}-{YYMMDD}-{HHmm}.
     * Contoh: RCP-MHW110-250616-1430
     * Tambah suffix angka (-1, -2, ...) jika ID yang sama sudah wujud
     * (berlaku jika dua pelajar hadir pada minit yang sama).
     */
    private function generateReceiptId(string $activityCode): string
    {
        $now     = now();
        $base    = 'RCP-' . strtoupper($activityCode) . '-' . $now->format('ymd') . '-' . $now->format('Hi');
        $attempt = 0;

        do {
            $id = $base . ($attempt > 0 ? '-' . $attempt : '');
            $attempt++;
        } while (AttendanceSubmission::where('receipt_id', $id)->exists() && $attempt < 100);

        return $id;
    }
}
