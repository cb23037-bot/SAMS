<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Restriction extends Model
{
    protected $fillable = [
        'user_id', 'restriction_type', 'status', 'applied_date', 'lifted_date', 'lifted_by',
    ];

    protected $casts = [
        'applied_date' => 'date',
        'lifted_date'  => 'date',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public static function isRestricted(int $userId): bool
    {
        return self::where('user_id', $userId)->where('status', 'active')->exists();
    }
}
