<?php

namespace App\Http\Middleware;

use App\Models\Restriction;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class CheckAcademicAccess
{
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
