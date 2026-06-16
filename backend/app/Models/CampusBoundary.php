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
     * getActiveBoundary()
     *
     * Retrieves the currently active campus boundary record from the database.
     * Only one boundary should be active at a time. Returns null if none is found.
     * Called before starting an attendance session to attach the boundary to it.
     *
     * Returns: CampusBoundary — The active boundary record, or null if not configured.
     */
    public static function getActiveBoundary(): ?self
    {
        return static::where('status', 'active')->first();
    }

    /**
     * verifyLocation(gps_latitude, gps_longitude, campus_boundary_id)
     *
     * Checks whether a student's GPS coordinates are within the permitted
     * campus boundary radius. Finds the boundary by ID, calculates the
     * distance using the Haversine formula, and compares it to the allowed radius.
     *
     * @param  float $lat        — Student's current GPS latitude.
     * @param  float $lng        — Student's current GPS longitude.
     * @param  int   $boundaryId — The campus boundary ID to check against.
     * Returns: Boolean — true if the student is within the allowed radius, false otherwise.
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

    /**
     * calculateDistance(gps_latitude, gps_longitude, center_latitude, center_longitude)
     *
     * Calculates the distance in meters between a student's GPS position and
     * the campus center point using the Haversine formula.
     * The Haversine formula accounts for the curvature of the Earth to give
     * an accurate ground distance between two coordinate pairs.
     *
     * @param  float $lat1 — Student's GPS latitude.
     * @param  float $lng1 — Student's GPS longitude.
     * @param  float $lat2 — Campus center latitude.
     * @param  float $lng2 — Campus center longitude.
     * Returns: Decimal — Distance in meters between the two coordinates.
     */
    public static function calculateDistance(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $earthRadius = 6371000; // Earth radius in meters

        $latDelta = deg2rad($lat2 - $lat1);
        $lngDelta = deg2rad($lng2 - $lng1);

        $a = sin($latDelta / 2) * sin($latDelta / 2)
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2))
            * sin($lngDelta / 2) * sin($lngDelta / 2);

        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));

        return $earthRadius * $c;
    }
}
