<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AcademicSession extends Model
{
    protected $fillable = ['session_name', 'is_active', 'is_registration_open'];
}