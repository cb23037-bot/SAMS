<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Activity;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * Menguruskan CRUD untuk aktiviti kurikulum (Module 2).
 *
 * Semua operasi tulis (store, update, destroy) adalah untuk staf Pusat Adab
 * sahaja. Index boleh diakses oleh semua pengguna yang telah log masuk.
 */
class ActivityController extends Controller
{
    // GET /api/activities
    // Kembalikan semua aktiviti bersama slot masing-masing, diisih terbaru dahulu.
    public function index(Request $request): JsonResponse
    {
        $activities = Activity::with('slots')->orderByDesc('created_at')->get();

        return response()->json([
            'status'     => 'success',
            'activities' => $activities->map(fn($a) => self::activityArray($a))->values(),
        ]);
    }

    // POST /api/activities  (adab only)
    // Kod aktiviti dijana secara automatik dari inisial nama jika tidak diisi.
    public function store(Request $request): JsonResponse
    {
        $this->requireAdab($request);

        $validated = $request->validate([
            'name'          => ['required', 'string', 'max:255'],
            'code'          => ['nullable', 'string', 'max:50', 'unique:activities,code'],
            'whatsapp_link' => ['nullable', 'string', 'max:255'],
            'description'   => ['nullable', 'string'],
            'location'      => ['required', 'string', 'max:255'],
        ]);

        // Jana kod automatik jika tidak diisi; code sentiasa uppercase
        $validated['code'] = !empty($validated['code'])
            ? strtoupper($validated['code'])
            : $this->generateCode($validated['name']);

        $activity = Activity::create($validated);

        return response()->json([
            'status'   => 'success',
            'activity' => self::activityArray($activity->load('slots')),
        ], 201);
    }

    // PUT /api/activities/{activity}  (adab only)
    // Kod mesti unik kecuali untuk aktiviti yang sama (ignore current id).
    public function update(Request $request, Activity $activity): JsonResponse
    {
        $this->requireAdab($request);

        $validated = $request->validate([
            'name'          => ['required', 'string', 'max:255'],
            'code'          => ['required', 'string', 'max:50', Rule::unique('activities', 'code')->ignore($activity->id)],
            'whatsapp_link' => ['nullable', 'string', 'max:255'],
            'description'   => ['nullable', 'string'],
            'location'      => ['required', 'string', 'max:255'],
        ]);

        // Kosongkan string kosong kepada null supaya DB tidak simpan string kosong
        $validated['code']          = strtoupper($validated['code']);
        $validated['whatsapp_link'] = !empty($validated['whatsapp_link']) ? $validated['whatsapp_link'] : null;
        $validated['description']   = !empty($validated['description']) ? $validated['description'] : null;

        $activity->update($validated);

        return response()->json([
            'status'   => 'success',
            'activity' => self::activityArray($activity->load('slots')),
        ]);
    }

    // DELETE /api/activities/{activity}  (adab only)
    public function destroy(Request $request, Activity $activity): JsonResponse
    {
        $this->requireAdab($request);

        $activity->delete();

        return response()->json(['status' => 'success', 'message' => 'Activity deleted.']);
    }

    /**
     * Tukar model Activity kepada array JSON yang dihantar ke frontend.
     * Static supaya boleh dipanggil dari ActivityRegistrationController juga.
     */
    public static function activityArray(Activity $activity): array
    {
        return [
            'id'            => $activity->id,
            'name'          => $activity->name,
            'code'          => $activity->code,
            'whatsapp_link' => $activity->whatsapp_link,
            'description'   => $activity->description,
            'location'      => $activity->location,
            'slots'         => $activity->slots->map(fn($s) => ActivitySlotController::slotArray($s))->values()->toArray(),
        ];
    }

    /**
     * Jana kod aktiviti unik dari inisial perkataan nama aktiviti + nombor rawak.
     * Contoh: "Mental Health Talk" → "MHT" + "482" → "MHT482".
     * Loop semula jika kod yang dijana sudah wujud dalam database.
     */
    private function generateCode(string $name): string
    {
        $words  = preg_split('/\s+/', trim($name));
        $prefix = implode('', array_map(fn($w) => strtoupper($w[0]), array_filter($words)));
        do {
            $code = $prefix . rand(100, 999);
        } while (Activity::where('code', $code)->exists());

        return $code;
    }
}
