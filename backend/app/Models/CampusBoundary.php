<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * CampusBoundary — Entity Model
 * Requirement ID : SAMS-PACK-403
 * Responsibility : Manages campus GPS boundary information used to verify whether
 *                  students are within the permitted campus area.
 *
 * Attributes:
 *   campus_boundary_id    int
 *   campus_name           String
 *   center_latitude       Decimal
 *   center_longitude      Decimal
 *   allowed_radius_meter  int
 *   status                String
 *   created_at            Timestamp
 *   updated_at            Timestamp
 */
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

    /**
     * getActiveBoundary() — CampusBoundary|null
     * SAMS-PACK-403
     *
     * Retrieves the currently active campus boundary configuration.
     * Returns null if no active boundary is configured.
     *
     * Algorithm:
     *   FIND campus boundary WHERE status = "active"
     *   IF boundary found THEN RETURN boundary ELSE RETURN null
     */
    public static function getActiveBoundary(): ?self
    {
        return self::where('status', 'active')->first();
    }

    /**
     * verifyLocation(gps_latitude, gps_longitude, campus_boundary_id) — Boolean
     * SAMS-PACK-403
     *
     * Checks whether the student's GPS coordinates are within the allowed campus radius.
     *
     * Algorithm:
     *   CALL calculateDistance(student_latitude, student_longitude, center_latitude, center_longitude)
     *   IF distance <= allowed_radius_meter THEN RETURN true ELSE RETURN false
     */
    public static function verifyLocation(float $lat, float $lng, int $boundaryId): bool
    {
        $boundary = self::find($boundaryId);
        if (!$boundary) return false;
        $distance = self::calculateDistance($lat, $lng, $boundary->center_latitude, $boundary->center_longitude);
        return $distance <= $boundary->allowed_radius_meter;
    }

    /**
     * calculateDistance(gps_latitude, gps_longitude, center_latitude, center_longitude) — Decimal
     * SAMS-PACK-403
     *
     * Calculates the straight-line distance (in metres) between the student's GPS coordinate
     * and the campus centre using the Haversine formula.
     *
     * Algorithm:
     *   CALCULATE distance between student GPS coordinate and campus center
     *   RETURN distance in metres
     */
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
