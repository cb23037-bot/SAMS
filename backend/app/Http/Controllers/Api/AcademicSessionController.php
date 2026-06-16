<?php
namespace App\Http\Controllers\Api;

use App\Models\AcademicSession;
use Illuminate\Http\Request;
use App\Http\Controllers\Controller;



class AcademicSessionController extends Controller
{
    public function index()
    {
        return AcademicSession::orderBy('created_at', 'desc')->get();
    }

    public function store(Request $request)
    {
        $request->validate(['session_name' => 'required|string']);

        // Close all existing sessions before creating the new one
        AcademicSession::query()->update([
            'is_registration_open' => false,
            'is_active'            => false,
        ]);

        return AcademicSession::create(['session_name' => $request->session_name]);
    }

    public function updateRegistration(Request $request, $id)
    {
        $session = AcademicSession::findOrFail($id);
        $session->is_registration_open = $request->is_registration_open;
        $session->save();
        return response()->json(['message' => 'Status updated']);
    }

public function setRegistrationStatus(Request $request, $id) {
    $session = AcademicSession::findOrFail($id);

    $request->validate(['is_registration_open' => 'required']);

    $isOpen = filter_var($request->is_registration_open, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE)
              ?? (bool) $request->is_registration_open;

    // Always wipe open state from every session first — prevents stale open records
    AcademicSession::query()->update([
        'is_registration_open' => false,
        'is_active'            => false,
    ]);

    if ($isOpen) {
        // Then mark only this session as open
        $session->is_registration_open = true;
        $session->is_active            = true;
        $session->save();
    }

    return response()->json(['message' => 'Registration status updated', 'session' => $session->fresh()]);
}
    

    public function destroy($id)
    {
        AcademicSession::destroy($id);
        return response()->json(['message' => 'Session deleted']);
    }

    public function getActiveSession()
{
    // Return the single session that has registration open, or null if none
    $session = AcademicSession::where('is_registration_open', true)
                              ->where('is_active', true)
                              ->latest()
                              ->first();

    return response()->json($session);
}

    // Utility: force-close all sessions (call once from registrar if DB has stale data)
    public function closeAll()
    {
        AcademicSession::query()->update([
            'is_registration_open' => false,
            'is_active'            => false,
        ]);
        return response()->json(['message' => 'All sessions closed']);
    }
}