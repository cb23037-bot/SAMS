<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Fee extends Model
{
    protected $fillable = [
        'student_id', 'semester', 'description',
        'total_amount', 'outstanding_amount', 'due_date', 'status',
    ];

    protected $casts = [
        'total_amount'       => 'float',
        'outstanding_amount' => 'float',
        'due_date'           => 'date',
    ];

    public function student(): BelongsTo
    {
        return $this->belongsTo(Student::class);
    }

    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class)->orderByDesc('created_at');
    }

    // Convenience accessor so existing code can still read ->amount_paid
    // Returns the amount already paid: total minus the current outstanding balance.
    // Clamped to 0 so it never goes negative due to floating-point drift.
    public function getAmountPaidAttribute(): float
    {
        return max(0.0, $this->total_amount - $this->outstanding_amount);
    }

    // Recalculates the fee's outstanding_amount and status based on the sum of
    // all successful payments. Must be called after every payment is created or
    // voided so the fee record stays in sync.
    // Sets status to 'Paid', 'Partial', or 'Unpaid' and saves to the database.
    public function recalculate(): void
    {
        $paid = (float) $this->payments()->where('status', 'Success')->sum('amount');

        $this->outstanding_amount = max(0.0, $this->total_amount - $paid);
        $this->status = match (true) {
            $paid >= $this->total_amount => 'Paid',
            $paid > 0                   => 'Partial',
            default                     => 'Unpaid',
        };
        $this->save();
    }
}
