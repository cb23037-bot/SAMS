<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Model untuk aktiviti kurikulum (jadual: activities).
 *
 * Satu aktiviti boleh mempunyai banyak slot masa (ActivitySlot).
 * Field 'cats' menentukan jumlah kredit CATs yang akan diberikan
 * kepada pelajar apabila tuntutan mereka diluluskan (default: 2).
 */
class Activity extends Model
{
    use HasFactory;

    // Field yang boleh diisi secara mass-assignment
    protected $fillable = ['name', 'code', 'whatsapp_link', 'description', 'location', 'cats'];

    /**
     * Slot masa yang berkaitan dengan aktiviti ini.
     * Diisih mengikut tarikh (terdekat dahulu) untuk paparan yang konsisten.
     */
    public function slots(): HasMany
    {
        return $this->hasMany(ActivitySlot::class)->orderBy('date');
    }
}
