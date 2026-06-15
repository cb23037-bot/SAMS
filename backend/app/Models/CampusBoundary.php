<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CampusBoundary extends Model
{
    protected $table = 'campus_boundaries';

    protected $primaryKey = 'campus_boundary_id';

    protected $fillable = [
        'campus_name',
        'center_latitude',
        'center_longitude',
        'allowed_radius_meter',
        'status',
    ];

    /**
     * Get the currently active campus boundary.
     */
    public static function getActiveBoundary(): ?self
    {
        return static::where('status', 'active')->first();
    }

    /**
     * Calculate the distance in meters between two GPS coordinates using the Haversine formula.
     */
    public static function calculateDistance(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $earthRadius = 6371000; // meters

        $latDelta = deg2rad($lat2 - $lat1);
        $lngDelta = deg2rad($lng2 - $lng1);

        $a = sin($latDelta / 2) * sin($latDelta / 2)
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2))
            * sin($lngDelta / 2) * sin($lngDelta / 2);

        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));

        return $earthRadius * $c;
    }

    /**
     * Check whether a GPS coordinate is within the allowed radius of a campus boundary.
     */
    public static function verifyLocation(float $lat, float $lng, int $boundaryId): bool
    {
        $boundary = static::find($boundaryId);

        if (!$boundary) {
            return false;
        }

        $distance = static::calculateDistance(
            $lat,
            $lng,
            (float) $boundary->center_latitude,
            (float) $boundary->center_longitude
        );

        return $distance <= $boundary->allowed_radius_meter;
    }
}
