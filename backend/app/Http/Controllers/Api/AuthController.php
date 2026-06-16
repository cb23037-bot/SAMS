<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Api\ProfileController;
use App\Mail\PasswordResetOtpMail;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;

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

    // POST /api/forgot-password  { email }
    public function forgotPassword(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'email'],
        ]);

        $email = strtolower($validated['email']);
        $user = User::query()->where('email', $email)->first();

        if (!$user) {
            return response()->json([
                'status' => 'error',
                'message' => 'No account found with that email address.',
            ], 404);
        }

        $otp = (string) random_int(100000, 999999);

        DB::table('password_reset_tokens')->updateOrInsert(
            ['email' => $email],
            ['token' => Hash::make($otp), 'created_at' => now()],
        );

        Mail::to($email)->send(new PasswordResetOtpMail($otp));

        return response()->json([
            'status' => 'success',
            'message' => 'A verification code has been sent to your email.',
        ]);
    }

    // POST /api/reset-password  { email, otp, password }
    public function resetPassword(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'email'],
            'otp' => ['required', 'string'],
            'password' => ['required', 'string', 'min:8'],
        ]);

        $email = strtolower($validated['email']);
        $record = DB::table('password_reset_tokens')->where('email', $email)->first();

        if (!$record || !Hash::check($validated['otp'], $record->token)) {
            return response()->json([
                'status' => 'error',
                'message' => 'Invalid verification code.',
            ], 422);
        }

        if (now()->diffInMinutes($record->created_at) > 15) {
            return response()->json([
                'status' => 'error',
                'message' => 'Verification code has expired. Please request a new one.',
            ], 422);
        }

        $user = User::query()->where('email', $email)->first();

        if (!$user) {
            return response()->json([
                'status' => 'error',
                'message' => 'No account found with that email address.',
            ], 404);
        }

        $user->update(['password' => $validated['password']]);

        DB::table('password_reset_tokens')->where('email', $email)->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'Password has been reset successfully.',
        ]);
    }
}
