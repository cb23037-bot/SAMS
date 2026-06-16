<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * CampusBoundary Model — SAMS-PACK-403
 *
 * Manages campus GPS boundary information used to verify whether students
 * are within the permitted campus area when submitting attendance.
 *
 * Attributes:
 *   - campus_boundary_id   : int       — Primary key, unique boundary identifier.
 *   - campus_name          : String    — Name of the campus location.
 *   - center_latitude      : Decimal   — GPS latitude of the campus center point.
 *   - center_longitude     : Decimal   — GPS longitude of the campus center point.
 *   - allowed_radius_meter : int       — Maximum allowed distance from center in meters.
 *   - status               : String    — Boundary status: 'active' or 'inactive'.
 *   - created_at           : Timestamp — Record creation timestamp.
 *   - updated_at           : Timestamp — Record last update timestamp.
 */
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

    // =========================================================================
    // SDD Methods — SAMS-PACK-403
    // =========================================================================

    /**
     * Get the currently active campus boundary.
     * Returns null if none is found.
     * Called before starting an attendance session to attach the boundary to it.
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
