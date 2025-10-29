<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Employee;

class EmployeeSeeder extends Seeder
{
    public function run(): void
    {
        // Clear existing data first
        Employee::truncate();
        
        $employees = [
            [
                'name' => 'John Doe',
                'email' => 'john@example.com',
                'position' => 'Software Engineer',
                'department' => 'Engineering',
                'salary' => 75000.00,
                'hire_date' => '2023-01-15'
            ],
            [
                'name' => 'Jane Smith',
                'email' => 'jane@example.com',
                'position' => 'Product Manager',
                'department' => 'Product',
                'salary' => 85000.00,
                'hire_date' => '2022-06-20'
            ],
            [
                'name' => 'Bob Johnson',
                'email' => 'bob@example.com',
                'position' => 'Designer',
                'department' => 'Design',
                'salary' => 70000.00,
                'hire_date' => '2023-03-10'
            ]
        ];

        foreach ($employees as $employee) {
            Employee::create($employee);
        }
    }
}
