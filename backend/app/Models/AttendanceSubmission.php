<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Model untuk rekod kehadiran pelajar ke aktiviti kurikulum (jadual: attendance_submissions).
 *
 * Satu rekod = satu pelajar telah hadir ke satu slot aktiviti.
 * Berbeza dengan ActivityRegistration — rekod ini dibuat SEMASA attend,
 * bukan semasa daftar. Ia menyimpan bukti kehadiran (foto + GPS) dan
 * maklumat resit yang digunakan untuk jana PDF receipt.
 *
 * 'receipt_id'   : ID boleh baca, contoh: RCP-MHW110-250616-1430
 * 'receipt_hash' : SHA-256 hash untuk sahkan kesahihan resit
 */
class AttendanceSubmission extends Model
{
    use HasFactory;

    // Field yang boleh diisi secara mass-assignment
    protected $fillable = [
        'user_id',
        'activity_slot_id',
        'attendance_code_submitted', // Kod yang dimasukkan pelajar semasa attend
        'photo_path',                // Path foto selfie di storage/public/attendance_photos/
        'latitude',                  // Koordinat GPS (nullable)
        'longitude',
        'address',                   // Alamat terbalik dari koordinat GPS (nullable)
        'receipt_id',                // ID unik resit kehadiran
        'receipt_hash',              // Hash SHA-256 untuk pengesahan integriti resit
    ];

    /**
     * Pelajar yang membuat submission kehadiran ini.
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Slot aktiviti yang dihadiri.
     * Foreign key eksplisit diperlukan kerana nama lajur ialah 'activity_slot_id'.
     */
    public function slot(): BelongsTo
    {
        return $this->belongsTo(ActivitySlot::class, 'activity_slot_id');
    }
}
