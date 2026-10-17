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
        $school = School::firstOrCreate(['id' => '11111111-1111-1111-1111-111111111111'], ['name' => 'Ecole Demo']);
        $surv = User::firstOrCreate(['phone' => '+212600000088'], ['school_id' => $school->id, 'name' => 'Sara', 'role' => 'surveillant', 'locale' => 'fr']);
        $surv->tokens()->delete();
        $token = $surv->createToken('dev')->plainTextToken;
        $parent = User::firstOrCreate(['phone' => '+212600000099'], ['school_id' => $school->id, 'name' => 'Parent', 'role' => 'parent', 'locale' => 'fr']);
        $child = Child::firstOrCreate(['school_id' => $school->id, 'first_name' => 'Yasmine', 'last_name' => 'ElFassi'], ['class_name' => 'CP-A']);
        $parent->children()->syncWithoutDetaching([$child->id]);
        PickupRequest::where('school_id', $school->id)->delete();
        PickupRequest::create(['school_id' => $school->id, 'child_id' => $child->id, 'requested_by' => $parent->id, 'idempotency_key' => (string) Str::uuid(), 'status' => 'requested']);
        $this->info("TOKEN=$token");
    }
}
