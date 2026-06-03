<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Api\ProfileController;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function login(Request $request): JsonResponse
    {
        $credentials = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $email = strtolower($credentials['email']);

        if (!str_ends_with($email, '@adab.umpsa.edu.my')) {
            return response()->json([
                'status' => 'error',
                'message' => 'Only @adab.umpsa.edu.my email addresses are allowed.',
            ], 422);
        }

        $user = User::query()->where('email', $email)->first();

        if (
            !$user ||
            !Hash::check($credentials['password'], $user->password)
        ) {
            return response()->json([
                'status' => 'error',
                'message' => 'Invalid email or password.',
            ], 401);
        }

        $token = $user->createToken($user->role . '-session')->plainTextToken;

        return response()->json([
            'status' => 'success',
            'user'   => ProfileController::userArray($user),
            'token'  => $token,
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()?->currentAccessToken()?->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'Logout successful.',
        ]);
    }
}
