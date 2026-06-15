<?php

namespace App\Http\Controllers;

/**
 * AuthController — Control Class
 * Requirement ID : SAMS-PACK-401
 * Responsibility : Handles user authentication — login, logout, and token retrieval.
 *                  Issues Laravel Sanctum API tokens upon successful login.
 *                  Routes apply to both lecturer and student roles.
 *
 * Attributes:
 *   email     String
 *   password  String
 *   token     String
 *   userRole  String
 *
 * Methods:
 *   login(email, password)  — Authenticates user and returns Sanctum token.
 *   logout(token)           — Revokes the current access token.
 *   me(token)               — Returns the authenticated user profile.
 */

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class AuthController extends Controller
{
    /**
     * login(email, password) — JsonResponse
     * SAMS-PACK-401
     * Route: POST /api/login
     *
     * Algorithm:
     *   VALIDATE email (required, email format) AND password (required, string)
     *   IF validation fails THEN RETURN 422 with errors
     *   CALL User.attemptLogin(email, password)
     *   IF user not found or inactive or password mismatch THEN RETURN 401
     *   CREATE Sanctum token for user
     *   RETURN 200 with token and user profile (id, name, email, role, student_id, ...)
     */
    public function login(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'email'    => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed.',
                'errors'  => $validator->errors(),
            ], 422);
        }

        $user = User::attemptLogin($request->email, $request->password);

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid email or password.',
            ], 401);
        }

        $token = $user->createToken('sams-api-token')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Login successful.',
            'token'   => $token,
            'user'    => [
                'id'           => $user->id,
                'name'         => $user->name,
                'email'        => $user->email,
                'role'         => $user->role,
                'student_id'   => $user->student_id,
                'course'       => $user->course,
                'phone_number' => $user->phone_number,
                'status'       => $user->status,
            ],
        ]);
    }

    /**
     * logout(token) — JsonResponse
     * SAMS-PACK-401
     * Route: POST /api/logout  (requires auth:sanctum)
     *
     * Algorithm:
     *   GET current access token from authenticated user
     *   DELETE current access token (revoke)
     *   RETURN 200 success message
     */
    public function logout(Request $request)
    {
        $request->user()?->currentAccessToken()?->delete();

        return response()->json([
            'success' => true,
            'message' => 'Logged out successfully.',
        ]);
    }

    /**
     * me(token) — JsonResponse
     * SAMS-PACK-401
     * Route: GET /api/me  (requires auth:sanctum)
     *
     * Algorithm:
     *   GET authenticated user from Sanctum token
     *   RETURN 200 with full user object
     */
    public function me(Request $request)
    {
        return response()->json([
            'success' => true,
            'user'    => $request->user(),
        ]);
    }
}
