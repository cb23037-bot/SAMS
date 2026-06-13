<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

// SAMS-PACK-403
class CampusBoundary extends Model
{
    protected $primaryKey = 'campus_boundary_id';

    protected $fillable = [
        'campus_name', 'center_latitude', 'center_longitude',
        'allowed_radius_meter', 'status',
    ];

    protected $casts = [
        'center_latitude'  => 'float',
        'center_longitude' => 'float',
    ];

    // SAMS-PACK-403: getActiveBoundary()
    public static function getActiveBoundary(): ?self
    {
        return self::where('status', 'active')->first();
    }

    // SAMS-PACK-403: verifyLocation(gps_latitude, gps_longitude, campus_boundary_id)
    public static function verifyLocation(float $lat, float $lng, int $boundaryId): bool
    {
        $boundary = self::find($boundaryId);
        if (!$boundary) return false;
        $distance = self::calculateDistance($lat, $lng, $boundary->center_latitude, $boundary->center_longitude);
        return $distance <= $boundary->allowed_radius_meter;
    }

    // SAMS-PACK-403: calculateDistance() — Haversine formula
    public static function calculateDistance(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $earthRadius = 6371000; // metres
        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);
        $a = sin($dLat / 2) ** 2
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2))
            * sin($dLng / 2) ** 2;
        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));
        return $earthRadius * $c;
    }
}
