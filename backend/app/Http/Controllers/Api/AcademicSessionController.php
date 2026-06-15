<?php
namespace App\Http\Controllers\Api;

use App\Models\AcademicSession;
use Illuminate\Http\Request;
use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\Log;



class AcademicSessionController extends Controller
{
    public function index()
    {
        return AcademicSession::orderBy('created_at', 'desc')->get();
    }

    public function store(Request $request)
    {
        $request->validate(['session_name' => 'required|string']);
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
    
    $session->is_registration_open = $request->is_registration_open;
    $session->save();
    
    return response()->json(['message' => 'Registration status updated']);
}
    

    public function destroy($id)
    {
        return AcademicSession::destroy($id);
    }

    public function getActiveSession()
{
    // Find the session where registration is open
    Log::info("getActiveSession was called!");
    $session = AcademicSession::where('is_registration_open', 1)->first();
    
    // Return the session data, or null if nothing is found
    return response()->json($session);
}
}