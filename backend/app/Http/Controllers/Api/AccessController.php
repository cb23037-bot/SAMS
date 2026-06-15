<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AccessController extends Controller
{
    private static function currentAccess(): string
    {
        return DB::table('settings')->where('key', 'student_access')->value('value') ?? 'open';
    }

    // GET /api/adab/access  (adab only)
    public function show(Request $request): JsonResponse
    {
        $this->requireAdab($request);
        return response()->json(['student_access' => self::currentAccess()]);
    }

    // PUT /api/adab/access  { status: 'open'|'closed' }  (adab only)
    public function update(Request $request): JsonResponse
    {
        $this->requireAdab($request);

        $request->validate(['status' => ['required', 'in:open,closed']]);

        DB::table('settings')->updateOrInsert(
            ['key' => 'student_access'],
            ['value' => $request->status, 'updated_at' => now()]
        );

        return response()->json(['student_access' => $request->status]);
    }

    // GET /api/student/access  (any authenticated user — students use this)
    public function studentCheck(): JsonResponse
    {
        return response()->json(['student_access' => self::currentAccess()]);
    }
}
