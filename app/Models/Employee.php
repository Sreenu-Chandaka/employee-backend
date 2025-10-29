<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Employee extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'email',
        'position',
        'department',
        'salary',
        'hire_date'
    ];

    protected $casts = [
        'salary' => 'decimal:2',
        'hire_date' => 'date'
    ];
}
