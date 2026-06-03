<?php

namespace App\Http\Controllers;

use Illuminate\Foundation\Auth\Access\AuthorizesRequests;
use Illuminate\Foundation\Validation\ValidatesRequests;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller as BaseController;

class Controller extends BaseController
{
    use AuthorizesRequests, ValidatesRequests;

    protected function requireAdab(Request $request): void
    {
        if ($request->user()->role !== 'adab') {
            abort(403, 'Unauthorized.');
        }
    }

    protected function requireStudent(Request $request): void
    {
        if ($request->user()->role !== 'student') {
            abort(403, 'Unauthorized.');
        }
    }
}
