<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Activity;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ActivityController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $activities = Activity::with('slots')->orderByDesc('created_at')->get();

        return response()->json([
            'status'     => 'success',
            'activities' => $activities->map(fn($a) => self::activityArray($a))->values(),
        ]);
    }

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

        $validated['code'] = !empty($validated['code'])
            ? strtoupper($validated['code'])
            : $this->generateCode($validated['name']);

        $activity = Activity::create($validated);

        return response()->json([
            'status'   => 'success',
            'activity' => self::activityArray($activity->load('slots')),
        ], 201);
    }

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

        $validated['code']          = strtoupper($validated['code']);
        $validated['whatsapp_link'] = !empty($validated['whatsapp_link']) ? $validated['whatsapp_link'] : null;
        $validated['description']   = !empty($validated['description']) ? $validated['description'] : null;

        $activity->update($validated);

        return response()->json([
            'status'   => 'success',
            'activity' => self::activityArray($activity->load('slots')),
        ]);
    }

    public function destroy(Request $request, Activity $activity): JsonResponse
    {
        $this->requireAdab($request);

        $activity->delete();

        return response()->json(['status' => 'success', 'message' => 'Activity deleted.']);
    }

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
