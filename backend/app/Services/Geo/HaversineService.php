<?php

declare(strict_types=1);

namespace App\Services\Geo;

class HaversineService
{
    public const EARTH_RADIUS_METERS = 6371000.0;

    /**
     * Calcule la distance en mètres entre deux coordonnées (formule Haversine).
     * Arrondie à l'entier le plus proche.
     */
    public function calculateDistance(float $lat1, float $lng1, float $lat2, float $lng2): int
    {
        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);

        $a = sin($dLat / 2) * sin($dLat / 2) +
            cos(deg2rad($lat1)) * cos(deg2rad($lat2)) *
            sin($dLng / 2) * sin($dLng / 2);

        $c = 2 * atan2(sqrt($a), sqrt(1 - $a));

        return (int) round(self::EARTH_RADIUS_METERS * $c);
    }

    /**
     * Alias pour calculateDistance.
     */
    public function distanceMeters(float $lat1, float $lng1, float $lat2, float $lng2): int
    {
        return $this->calculateDistance($lat1, $lng1, $lat2, $lng2);
    }

    /**
     * Détermine l'état de proximité ('in_perimeter', 'approaching', 'out_of_zone').
     *
     * @param int $distanceMeters Distance calculée en mètres
     * @param int $radiusMeters Rayon du périmètre en mètres (défaut 50)
     * @return string
     */
    public function evaluateProximity(int $distanceMeters, int $radiusMeters = 50): string
    {
        $r = max(10, $radiusMeters);
        $maxApproach = min(3 * $r, 500);

        if ($distanceMeters <= $r) {
            return 'in_perimeter';
        }

        if ($distanceMeters <= $maxApproach) {
            return 'approaching';
        }

        return 'out_of_zone';
    }
}
