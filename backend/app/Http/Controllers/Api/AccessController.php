<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Mengurus kawalan akses pelajar secara sistem-wide.
 *
 * Nilai akses disimpan dalam jadual `settings` dengan key 'student_access'.
 * Nilai yang sah: 'open' (akses dibuka) | 'closed' (akses ditutup).
 * Default: 'open' jika rekod belum wujud dalam database.
 */
class AccessController extends Controller
{
    /**
     * Baca nilai akses semasa dari jadual settings.
     * Dipanggil oleh show(), update() dan studentCheck().
     */
    private static function currentAccess(): string
    {
        return DB::table('settings')->where('key', 'student_access')->value('value') ?? 'open';
    }

    // GET /api/adab/access  (adab only)
    // Digunakan oleh dashboard Pusat Adab untuk papar status semasa togol akses.
    public function show(Request $request): JsonResponse
    {
        $this->requireAdab($request);
        return response()->json(['student_access' => self::currentAccess()]);
    }

    // PUT /api/adab/access  { status: 'open'|'closed' }  (adab only)
    // Guna updateOrInsert supaya rekod dibuat jika belum ada, atau dikemaskini jika dah ada.
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
    // Dipanggil oleh app pelajar semasa booting untuk semak sama ada akses dibuka.
    public function studentCheck(): JsonResponse
    {
        return response()->json(['student_access' => self::currentAccess()]);
    }
}
