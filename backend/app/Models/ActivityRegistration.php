<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Model untuk pendaftaran pelajar ke slot aktiviti (jadual: activity_registrations).
 *
 * Satu rekod = satu pelajar mendaftar untuk satu slot.
 * 'claim_status' menjejak status tuntutan kredit CATs:
 *   'not_claimed' → pelajar daftar tapi belum hantar tuntutan
 *   'pending'     → tuntutan dihantar, menunggu keputusan Pusat Adab
 *   'claimed'     → tuntutan diluluskan oleh Pusat Adab
 *   'rejected'    → tuntutan ditolak oleh Pusat Adab
 */
class ActivityRegistration extends Model
{
    // Field yang boleh diisi secara mass-assignment
    protected $fillable = ['user_id', 'activity_slot_id', 'claim_status', 'proof_path', 'remarks', 'rejection_reason'];

    /**
     * Pelajar yang membuat pendaftaran ini.
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Slot aktiviti yang didaftar.
     * Foreign key eksplisit diperlukan kerana nama lajur ialah 'activity_slot_id'.
     */
    public function slot(): BelongsTo
    {
        return $this->belongsTo(ActivitySlot::class, 'activity_slot_id');
    }
}
