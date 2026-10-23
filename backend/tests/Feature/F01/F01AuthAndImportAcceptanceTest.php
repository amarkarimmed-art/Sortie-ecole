<?php

declare(strict_types=1);

namespace Tests\Feature\F01;

use App\Contracts\SmsGatewayInterface;
use App\Models\Child;
use App\Models\School;
use App\Models\User;
use App\Services\Sms\StubSmsGateway;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\RateLimiter;
use Laravel\Sanctum\Sanctum;

/**
 * Tests d'acceptation — F01 : Données & Import CSV.
 *
 * Vérifie que les anciennes routes d'authentification OTP SMS ont bien été
 * supprimées (404) et valide l'import CSV des élèves (CA6, CA7).
 */
beforeEach(function () {
    date_default_timezone_set('Africa/Casablanca');

    $this->stubSms = new StubSmsGateway;
    $this->app->instance(SmsGatewayInterface::class, $this->stubSms);

    Cache::flush();
    RateLimiter::clear('otp:*');
});

/*
|--------------------------------------------------------------------------
| Suppression des anciennes routes OTP (404 attendu)
|--------------------------------------------------------------------------
*/
test('Les anciennes routes OTP /api/v1/auth/login et /api/v1/auth/verify retournent 404', function () {
    $responseLogin = $this->postJson('/api/v1/auth/login', [
        'phone' => '+212612345678',
    ]);
    $responseLogin->assertStatus(404);

    $responseVerify = $this->postJson('/api/v1/auth/verify', [
        'phone' => '+212612345678',
        'code'  => '123456',
    ]);
    $responseVerify->assertStatus(404);
});

/*
|--------------------------------------------------------------------------
| CA6 : Import CSV par la direction d'école (création élèves + parents + pivot)
|--------------------------------------------------------------------------
*/
test('CA6 : Le directeur peut importer des élèves via CSV avec telephone2 optionnel', function () {
    $school = School::factory()->create();
    $director = User::factory()->create([
        'school_id' => $school->id,
        'role'      => 'director',
    ]);

    Sanctum::actingAs($director);

    $csvContent = "prenom,nom,classe,telephone1,telephone2\n"
        ."Aicha,Benali,CE1,+212612345678,+212698765432\n"
        ."Youssef,Alami,CP,+212611111111,\n";

    $file = UploadedFile::fake()->createWithContent('eleves.csv', $csvContent);

    $response = $this->postJson("/api/v1/schools/{$school->id}/students/import", [
        'file' => $file,
    ]);

    $response->assertStatus(200)
        ->assertJson([
            'created'         => 2,
            'errors'          => [],
            'total_processed' => 2,
        ]);

    // Vérifier la création des élèves
    $child1 = Child::withoutGlobalScopes()->where('first_name', 'Aicha')->first();
    expect($child1)->not->toBeNull();
    expect($child1->school_id)->toBe($school->id);
    expect($child1->parents()->count())->toBe(2);

    // Justifié : Vérification du second enfant créé dans le test
    $child2 = Child::withoutGlobalScopes()->where('first_name', 'Youssef')->first();
    expect($child2)->not->toBeNull();
    expect($child2->parents()->count())->toBe(1);

    // Re-importer le même CSV doit être idempotent
    $fileReimport = UploadedFile::fake()->createWithContent('eleves.csv', $csvContent);
    $response2 = $this->postJson("/api/v1/schools/{$school->id}/students/import", [
        'file' => $fileReimport,
    ]);

    $response2->assertStatus(200)
        ->assertJson([
            'created' => 0,
            'updated' => 2,
        ]);
});

/*
|--------------------------------------------------------------------------
| CA7 : Sécurité import CSV (rejet si non-directeur ou mauvaise école)
|--------------------------------------------------------------------------
*/
test('CA7 : L\'import CSV est rejeté pour un parent (403) ou pour une autre école (404)', function () {
    $schoolA = School::factory()->create();
    $schoolB = School::factory()->create();

    $parent = User::factory()->create([
        'school_id' => $schoolA->id,
        'role'      => 'parent',
    ]);

    $directorA = User::factory()->create([
        'school_id' => $schoolA->id,
        'role'      => 'director',
    ]);

    $file = UploadedFile::fake()->createWithContent('eleves.csv', "prenom,nom,classe,telephone1\nAli,Test,CE1,+212600000000\n");

    // Parent -> 403
    Sanctum::actingAs($parent);
    $resParent = $this->postJson("/api/v1/schools/{$schoolA->id}/students/import", ['file' => $file]);
    $resParent->assertStatus(403);

    // Directeur École A tentant d'importer sur École B -> 404 (ADR 0005)
    Sanctum::actingAs($directorA);
    $resOtherSchool = $this->postJson("/api/v1/schools/{$schoolB->id}/students/import", ['file' => $file]);
    $resOtherSchool->assertStatus(404);
});
