<?php

namespace App\Models;

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
    protected $table = 'attendance_submissions';

    protected $fillable = [
        'user_id',
        'activity_slot_id',
        'attendance_code_submitted',
        'photo_path',
        'latitude',
        'longitude',
        'address',
        'receipt_id',
        'receipt_hash',
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
     */
    public function slot(): BelongsTo
    {
        return $this->belongsTo(ActivitySlot::class, 'activity_slot_id');
    }
}
