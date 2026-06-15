<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Fee extends Model
{
    protected $fillable = [
        'user_id', 'semester', 'description', 'amount', 'amount_paid', 'due_date', 'status',
    ];

    protected $casts = [
        'amount'      => 'float',
        'amount_paid' => 'float',
        'due_date'    => 'date',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class);
    }

    public function recalculate(): void
    {
        $paid = $this->payments()->sum('amount');
        $this->amount_paid = $paid;
        $this->status = match (true) {
            $paid <= 0             => 'unpaid',
            $paid >= $this->amount => 'paid',
            default                => 'partial',
        };
        $this->save();
    }
}
