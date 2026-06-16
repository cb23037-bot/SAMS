<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Model untuk slot masa aktiviti kurikulum (jadual: activity_slots).
 *
 * Setiap slot mewakili satu sesi pelaksanaan aktiviti pada tarikh & masa tertentu.
 * 'registered' dikemaskini secara manual (increment/decrement) oleh
 * ActivityRegistrationController apabila pelajar mendaftar atau membatal.
 * 'attendance_code' adalah kod 6 aksara unik yang digunakan pelajar semasa attend.
 */
class ActivitySlot extends Model
{
    use HasFactory;

    // Field yang boleh diisi secara mass-assignment
    protected $fillable = ['activity_id', 'date', 'time', 'capacity', 'registered', 'attendance_code'];

    // Cast 'date' ke objek Carbon supaya boleh guna ->format() dalam controller
    protected $casts = ['date' => 'date'];

    /**
     * Aktiviti induk yang memiliki slot ini.
     */
    public function activity(): BelongsTo
    {
        return $this->belongsTo(Activity::class);
    }

    /**
     * Semua pendaftaran pelajar untuk slot ini.
     * Foreign key eksplisit diperlukan kerana nama lajur ialah 'activity_slot_id',
     * bukan 'activity_registration_id' (konvensyen Laravel standard).
     */
    public function registrations(): HasMany
    {
        return $this->hasMany(ActivityRegistration::class, 'activity_slot_id');
    }
}
