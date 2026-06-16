<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Subject extends Model
{
    protected $fillable = ['name', 'code', 'credit_hours'];

    
    protected $with = ['lectureSections', 'labSections'];
    
    public function lectureSections(): HasMany
    {
        return $this->hasMany(LectureSection::class);
    }

    public function labSections(): HasMany
    {
        return $this->hasMany(LabSection::class);
    }
}