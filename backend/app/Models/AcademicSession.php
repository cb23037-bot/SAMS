<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AcademicSession extends Model
{
    protected $fillable = ['session_name', 'is_active', 'is_registration_open'];

    // Cast boolean columns so JSON returns true/false, not 0/1
    protected $casts = [
        'is_active'             => 'boolean',
        'is_registration_open'  => 'boolean',
    ];
}