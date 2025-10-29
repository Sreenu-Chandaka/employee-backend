<?php

namespace App\Http\Controllers;

use App\Models\Employee;
use Illuminate\Http\Request;

class EmployeeController extends Controller
{
    public function index()
    {
        return Employee::all();
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|unique:employees',
            'position' => 'required|string',
            'department' => 'required|string',
            'salary' => 'required|numeric',
            'hire_date' => 'required|date'
        ]);

        return Employee::create($validated);
    }

    public function show(Employee $employee)
    {
        return $employee;
    }

    public function update(Request $request, Employee $employee)
    {
        $validated = $request->validate([
            'name' => 'string|max:255',
            'email' => 'email|unique:employees,email,' . $employee->id,
            'position' => 'string',
            'department' => 'string',
            'salary' => 'numeric',
            'hire_date' => 'date'
        ]);

        $employee->update($validated);
        return $employee;
    }

    public function destroy(Employee $employee)
    {
        $employee->delete();
        return response()->json(['message' => 'Employee deleted']);
    }
}
