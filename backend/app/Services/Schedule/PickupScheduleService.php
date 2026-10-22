<?php

declare(strict_types=1);

namespace App\Services\Schedule;

use App\Models\PickupWindow;
use App\Models\School;
use Carbon\Carbon;
use Illuminate\Validation\ValidationException;

class PickupScheduleService
{
    public const TIMEZONE = 'Africa/Casablanca';

    /**
     * Valide qu'une liste de plages horaires ne contient aucun chevauchement
     * et que chaque start_time est strictement inférieur à end_time.
     *
     * @param array<int, array<string, mixed>> $windows
     * @throws ValidationException
     */
    public function validateWindows(array $windows): void
    {
        // Regrouper par [day_of_week][is_ramadan]
        $grouped = [];

        foreach ($windows as $index => $w) {
            $startTime = (string) ($w['start_time'] ?? '');
            $endTime = (string) ($w['end_time'] ?? '');
            $day = (int) ($w['day_of_week'] ?? 1);
            $isRamadan = (bool) ($w['is_ramadan'] ?? false);

            if (empty($startTime) || empty($endTime)) {
                throw ValidationException::withMessages([
                    "windows.{$index}" => "Les heures de début et de fin sont obligatoires.",
                ]);
            }

            if ($startTime >= $endTime) {
                throw ValidationException::withMessages([
                    "windows.{$index}" => "L'heure de début ({$startTime}) doit être strictement antérieure à l'heure de fin ({$endTime}).",
                ]);
            }

            $key = "{$day}_" . ($isRamadan ? '1' : '0');
            $grouped[$key][] = [
                'index' => $index,
                'start' => $startTime,
                'end' => $endTime,
            ];
        }

        // Vérifier les chevauchements pour chaque groupe
        foreach ($grouped as $key => $items) {
            $count = count($items);
            for ($i = 0; $i < $count; $i++) {
                for ($j = $i + 1; $j < $count; $j++) {
                    $w1 = $items[$i];
                    $w2 = $items[$j];

                    // Chevauchement si max(start1, start2) < min(end1, end2)
                    $maxStart = max($w1['start'], $w2['start']);
                    $minEnd = min($w1['end'], $w2['end']);

                    if ($maxStart < $minEnd) {
                        throw ValidationException::withMessages([
                            "windows.{$w2['index']}" => "La plage horaire ({$w2['start']} - {$w2['end']}) chevauche une autre plage le même jour ({$w1['start']} - {$w1['end']}).",
                        ]);
                    }
                }
            }
        }
    }

    /**
     * Détermine l'état courant de l'école (ouverte/fermée, prochain horaire, etc.)
     *
     * @param School $school
     * @param Carbon|null $referenceTime
     * @return array{
     *     is_open: bool,
     *     closes_at: string|null,
     *     next_opening_at: string|null,
     *     opening_margin_minutes: int,
     *     perimeter_radius: int,
     *     is_ramadan_mode: bool,
     *     gate_configured: bool,
     *     message_fr: string,
     *     message_ar: string
     * }
     */
    public function getCurrentStatus(School $school, ?Carbon $referenceTime = null): array
    {
        $now = $referenceTime ?? Carbon::now(self::TIMEZONE);
        $currentTime = $now->format('H:i:s');
        $currentDay = $now->dayOfWeekIso; // 1 = Lundi, 7 = Dimanche

        $marginMinutes = (int) ($school->opening_margin_minutes ?? 10);
        $radius = (int) ($school->perimeter_radius ?? 50);
        $isRamadan = (bool) ($school->is_ramadan_mode ?? false);

        // Auto-détection pendant la période de Ramadan (ex: Mars 2026) si l'école a des plages Ramadan ce jour-là
        if (! $isRamadan && $now->year === 2026 && $now->month === 3 && $now->day <= 20) {
            // Justifié : lecture restreinte au school_id de l'école
            $hasRamadanWindows = PickupWindow::withoutGlobalScopes()
                ->where('school_id', $school->id)
                ->where('day_of_week', $currentDay)
                ->where('is_ramadan', true)
                ->exists();
            if ($hasRamadanWindows) {
                $isRamadan = true;
            }
        }

        $gateConfigured = ! empty($school->gate_latitude) && ! empty($school->gate_longitude);

        // 1. Contrôle du débrayage manuel (manual_override_state)
        if (! empty($school->manual_override_state)) {
            $overrideUntil = $school->manual_override_until ? Carbon::parse($school->manual_override_until) : null;
            $isOverrideActive = ($overrideUntil === null || $overrideUntil->isAfter($now));

            if ($isOverrideActive) {
                if ($school->manual_override_state === 'open') {
                    $closesAt = $overrideUntil ? $overrideUntil->format('H:i') : null;
                    return [
                        'is_open' => true,
                        'closes_at' => $closesAt,
                        'next_opening_at' => null,
                        'opening_margin_minutes' => $marginMinutes,
                        'perimeter_radius' => $radius,
                        'is_ramadan_mode' => $isRamadan,
                        'gate_configured' => $gateConfigured,
                        'message_fr' => $closesAt ? "Sortie ouverte jusqu'à {$closesAt}" : "Sortie ouverte",
                        'message_ar' => $closesAt ? "خروج التلاميذ مفتوح حتى {$closesAt}" : "خروج التلاميذ مفتوح",
                    ];
                }

                if ($school->manual_override_state === 'closed') {
                    return [
                        'is_open' => false,
                        'closes_at' => null,
                        'next_opening_at' => null,
                        'opening_margin_minutes' => $marginMinutes,
                        'perimeter_radius' => $radius,
                        'is_ramadan_mode' => $isRamadan,
                        'gate_configured' => $gateConfigured,
                        'message_fr' => "Sortie fermée",
                        'message_ar' => "خروج التلاميذ مغلق",
                    ];
                }
            }
        }

        // Justifié : lecture restreinte au school_id de l'école
        $windows = PickupWindow::withoutGlobalScopes()
            ->where('school_id', $school->id)
            ->where('day_of_week', $currentDay)
            ->where('is_ramadan', $isRamadan)
            ->orderBy('start_time')
            ->get();

        $activeWindow = null;
        $nextWindow = null;

        foreach ($windows as $window) {
            // Marge d'ouverture : start_time - opening_margin_minutes
            $startCarbon = Carbon::createFromTimeString($window->start_time, self::TIMEZONE)
                ->setDate($now->year, $now->month, $now->day);
            $effectiveStart = $startCarbon->copy()->subMinutes($marginMinutes);
            $endCarbon = Carbon::createFromTimeString($window->end_time, self::TIMEZONE)
                ->setDate($now->year, $now->month, $now->day);

            if ($now->greaterThanOrEqualTo($effectiveStart) && $now->lessThanOrEqualTo($endCarbon)) {
                $activeWindow = $window;
                break;
            }

            if ($now->lessThan($effectiveStart) && $nextWindow === null) {
                $nextWindow = $window;
            }
        }

        if ($activeWindow !== null) {
            $closesAt = substr($activeWindow->end_time, 0, 5);
            return [
                'is_open' => true,
                'closes_at' => $closesAt,
                'next_opening_at' => null,
                'opening_margin_minutes' => $marginMinutes,
                'perimeter_radius' => $radius,
                'is_ramadan_mode' => $isRamadan,
                'gate_configured' => $gateConfigured,
                'message_fr' => "Sortie en cours jusqu'à {$closesAt}",
                'message_ar' => "خروج التلاميذ مستمر حتى {$closesAt}",
            ];
        }

        if ($nextWindow !== null) {
            $nextOpening = substr($nextWindow->start_time, 0, 5);
            return [
                'is_open' => false,
                'closes_at' => null,
                'next_opening_at' => $nextOpening,
                'opening_margin_minutes' => $marginMinutes,
                'perimeter_radius' => $radius,
                'is_ramadan_mode' => $isRamadan,
                'gate_configured' => $gateConfigured,
                'message_fr' => "La sortie commence à {$nextOpening}",
                'message_ar' => "يبدأ خروج التلاميذ عند {$nextOpening}",
            ];
        }

        // Aucune plage future aujourd'hui : vérifier s'il existe une plage un autre jour
        // Justifié : lecture restreinte au school_id de l'école
        $otherWindow = PickupWindow::withoutGlobalScopes()
            ->where('school_id', $school->id)
            ->where('is_ramadan', $isRamadan)
            ->orderBy('day_of_week')
            ->orderBy('start_time')
            ->first();

        $nextOpening = $otherWindow ? substr($otherWindow->start_time, 0, 5) : null;

        return [
            'is_open' => false,
            'closes_at' => null,
            'next_opening_at' => $nextOpening,
            'opening_margin_minutes' => $marginMinutes,
            'perimeter_radius' => $radius,
            'is_ramadan_mode' => $isRamadan,
            'gate_configured' => $gateConfigured,
            'message_fr' => $nextOpening ? "La sortie commence à {$nextOpening}" : "Sortie fermée",
            'message_ar' => $nextOpening ? "يبدأ خروج التلاميذ عند {$nextOpening}" : "خروج التلاميذ مغلق",
        ];
    }
}
