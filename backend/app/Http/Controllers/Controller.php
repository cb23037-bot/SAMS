<?php

namespace App\Http\Controllers;

use Illuminate\Foundation\Auth\Access\AuthorizesRequests;
use Illuminate\Foundation\Validation\ValidatesRequests;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller as BaseController;

/**
 * Base controller untuk semua API controller dalam sistem SAMS.
 *
 * Menyediakan tiga helper method pengesahan peranan (role guard) yang
 * digunakan oleh semua controller lain — membuang 403 jika pengguna
 * semasa tidak mempunyai peranan yang diperlukan.
 */
class Controller extends BaseController
{
    use AuthorizesRequests, ValidatesRequests;

    /**
     * Pastikan pengguna yang membuat request mempunyai peranan 'adab'
     * (staf Pusat Adab). Digunakan oleh ActivityController,
     * ActivitySlotController, CreditClaimController dan AccessController.
     */
    protected function requireAdab(Request $request): void
    {
        if ($request->user()->role !== 'adab') {
            abort(403, 'Unauthorized.');
        }
    }

    /**
     * Pastikan pengguna yang membuat request mempunyai peranan 'student'.
     * Digunakan oleh ActivityRegistrationController dan AttendanceController.
     */
    protected function requireStudent(Request $request): void
    {
        if ($request->user()->role !== 'student') {
            abort(403, 'Unauthorized.');
        }
    }

    /**
     * Pastikan pengguna yang membuat request mempunyai peranan 'lecturer'.
     * Mengembalikan JSON 403 (bukan HTML abort) agar konsisten dengan
     * respons API lain.
     */
    protected function requireLecturer(Request $request): void
    {
        if (!$request->user() || $request->user()->role !== 'lecturer') {
            abort(response()->json([
                'message' => 'Unauthorized. Lecturer access required.'
            ], 403));
        }
    }
}
