<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LabSection extends Model
{
    protected $fillable = ['subject_id', 'section', 'instructor', 'schedule'];

    public function subject(): BelongsTo
    {
        return $this->belongsTo(Subject::class);
    }
}