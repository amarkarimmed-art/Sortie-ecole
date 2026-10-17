<?php

namespace App\Console\Commands;

use App\Models\Child;
use App\Models\PickupRequest;
use App\Models\School;
use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Str;

class DemoSeedCommand extends Command
{
    protected $signature = 'demo:seed';

    protected $description = 'Seed demo data and generate surveillant token';

    public function handle(): void
    {
        $schoolId = '11111111-1111-1111-1111-111111111111';
        $school = School::find($schoolId);
        if (! $school) {
            $school = new School();
            $school->id = $schoolId;
            $school->name = 'Ecole Demo';
            $school->save();
        }

        $surv = User::where('phone', '+212600000088')->first() ?? new User();
        $surv->phone = '+212600000088';
        $surv->school_id = $school->id;
        $surv->name = 'Sara';
        $surv->role = 'surveillant';
        $surv->locale = 'fr';
        $surv->save();

        $surv->tokens()->delete();
        $token = $surv->createToken('dev')->plainTextToken;

        $parent = User::where('phone', '+212600000099')->first() ?? new User();
        $parent->phone = '+212600000099';
        $parent->school_id = $school->id;
        $parent->name = 'Parent';
        $parent->role = 'parent';
        $parent->locale = 'fr';
        $parent->save();

        $child = Child::where('school_id', $school->id)
            ->where('first_name', 'Yasmine')
            ->where('last_name', 'ElFassi')
            ->first();
        if (! $child) {
            $child = new Child();
            $child->school_id = $school->id;
            $child->first_name = 'Yasmine';
            $child->last_name = 'ElFassi';
            $child->class_name = 'CP-A';
            $child->save();
        }

        $parent->children()->syncWithoutDetaching([$child->id]);

        PickupRequest::where('school_id', $school->id)->delete();
        PickupRequest::create([
            'school_id' => $school->id,
            'child_id' => $child->id,
            'requested_by' => $parent->id,
            'idempotency_key' => (string) Str::uuid(),
            'status' => 'class_notified',
            'called_at' => now(),
        ]);

        $this->info("TOKEN=$token");
        $this->info("SCHOOL_ID={$school->id}");
    }
}
