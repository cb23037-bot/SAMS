<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Sponsor extends Model
{
    protected $fillable = ['user_id', 'name', 'type', 'coverage', 'amount', 'status'];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
