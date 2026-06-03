<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProfileController extends Controller
{
    public function update(Request $request): JsonResponse
    {
        $this->requireStudent($request);

        $user = $request->user();

        $validated = $request->validate([
            'phone_number'     => ['nullable', 'string', 'max:20'],
            'current_semester' => ['nullable', 'string', 'max:50'],
            'personal_advisor' => ['nullable', 'string', 'max:255'],
            'address'          => ['nullable', 'string'],
        ]);

        $user->update($validated);

        return response()->json([
            'status' => 'success',
            'user'   => self::userArray($user),
        ]);
    }

    public static function userArray($user): array
    {
        return [
            'id'               => $user->id,
            'name'             => $user->name,
            'email'            => $user->email,
            'role'             => $user->role,
            'student_id'       => $user->student_id,
            'course'           => $user->course,
            'phone_number'     => $user->phone_number,
            'current_semester' => $user->current_semester,
            'personal_advisor' => $user->personal_advisor,
            'address'          => $user->address,
        ];
    }
}
