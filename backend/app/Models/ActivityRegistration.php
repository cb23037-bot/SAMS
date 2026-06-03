<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ActivityRegistration extends Model
{
    protected $fillable = ['user_id', 'activity_slot_id', 'claim_status', 'proof_path', 'remarks', 'rejection_reason'];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function slot(): BelongsTo
    {
        return $this->belongsTo(ActivitySlot::class, 'activity_slot_id');
    }
}
