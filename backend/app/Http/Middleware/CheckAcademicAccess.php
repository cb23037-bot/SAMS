<?php

namespace App\Http\Middleware;

use App\Models\Restriction;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class CheckAcademicAccess
{
    // Route middleware — blocks student requests when an active financial restriction exists.
    // Registered as the 'academic.access' alias in Kernel.php.
    // Applied to POST /student/registrations and POST /student/attendances so that
    // students with unpaid fees cannot register for courses or mark attendance.
    // Non-student roles (staff, treasury, admin) pass through without any check.
    // Returns 403 JSON with restriction=true when the student is blocked.
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        // Only enforce for students; staff roles are unaffected
        if ($user && $user->role === 'student' && Restriction::isRestricted($user->id)) {
            return response()->json([
                'message'          => 'Academic access restricted due to unpaid fees.',
                'restriction'      => true,
                'restriction_type' => 'financial_bar',
            ], 403);
        }

        return $next($request);
    }
}
