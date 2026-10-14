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
 * Tests d'acceptation — F01 : Comptes & Données (Authentification SMS + Import CSV).
 *
 * Couvre les critères d'acceptation CA1 à CA7.
 */
beforeEach(function () {
    date_default_timezone_set('Africa/Casablanca');

    // Utiliser le StubSmsGateway pour inspecter les SMS envoyés
    $this->stubSms = new StubSmsGateway;
    $this->app->instance(SmsGatewayInterface::class, $this->stubSms);

    Cache::flush();
    RateLimiter::clear('otp:*');
});

/*
|--------------------------------------------------------------------------
| CA1 : Demande de code OTP valide
|--------------------------------------------------------------------------
*/
test('CA1 : Un utilisateur existant peut demander un code OTP par SMS', function () {
    $school = School::factory()->create();
    $user = User::factory()->create([
        'school_id' => $school->id,
        'phone' => '+212612345678',
    ]);

    $response = $this->postJson('/api/v1/auth/login', [
        'phone' => '+212612345678',
    ]);

    $response->assertStatus(200)
        ->assertJson(['message' => 'Code envoyé par SMS.']);

    // Vérifier l'envoi du SMS via le Stub
    expect($this->stubSms->getSentMessages())->toHaveCount(1);
    expect($this->stubSms->getLastPhone())->toBe('+212612345678');
    expect($this->stubSms->getLastMessage())->toMatch('/[0-9]{6}/');

    // Vérifier la présence en cache
    $codeInCache = Cache::get('otp:code:+212612345678');
    expect($codeInCache)->not->toBeNull();
    expect(strlen($codeInCache))->toBe(6);
});

/*
|--------------------------------------------------------------------------
| CA2 : Demande de code OTP pour un numéro inconnu
|--------------------------------------------------------------------------
*/
test('CA2 : Un numéro inconnu retourne 404 sans envoyer de SMS', function () {
    $response = $this->postJson('/api/v1/auth/login', [
        'phone' => '+212699999999',
    ]);

    $response->assertStatus(404);
    expect($this->stubSms->getSentMessages())->toBeEmpty();
});

/*
|--------------------------------------------------------------------------
| CA3 : Vérification OTP valide et émission du token
|--------------------------------------------------------------------------
*/
test('CA3 : La vérification d\'un code OTP valide retourne un token Sanctum et le profil', function () {
    $school = School::factory()->create();
    $user = User::factory()->create([
        'school_id' => $school->id,
        'phone' => '+212612345678',
        'role' => 'parent',
    ]);

    Cache::put('otp:code:+212612345678', '123456', 300);

    $response = $this->postJson('/api/v1/auth/verify', [
        'phone' => '+212612345678',
        'code' => '123456',
    ]);

    $response->assertStatus(200)
        ->assertJsonStructure([
            'token',
            'user' => [
                'id',
                'name',
                'phone',
                'role',
                'locale',
                'school_id',
            ],
        ]);

    // L'OTP doit avoir été invalidé immédiatement (one-time)
    expect(Cache::get('otp:code:+212612345678'))->toBeNull();

    // Le téléphone doit être marqué vérifié
    $user->refresh();
    expect($user->phone_verified_at)->not->toBeNull();
});

/*
|--------------------------------------------------------------------------
| CA4 : Vérification OTP avec un code incorrect ou expiré
|--------------------------------------------------------------------------
*/
test('CA4 : Un mauvais code OTP ou un code expiré retourne 401', function () {
    $school = School::factory()->create();
    User::factory()->create([
        'school_id' => $school->id,
        'phone' => '+212612345678',
    ]);

    Cache::put('otp:code:+212612345678', '123456', 300);

    // Mauvais code
    $response = $this->postJson('/api/v1/auth/verify', [
        'phone' => '+212612345678',
        'code' => '000000',
    ]);

    $response->assertStatus(401);

    // Code expiré (absent du cache)
    Cache::forget('otp:code:+212612345678');

    $responseExpired = $this->postJson('/api/v1/auth/verify', [
        'phone' => '+212612345678',
        'code' => '123456',
    ]);

    $responseExpired->assertStatus(401);
});

/*
|--------------------------------------------------------------------------
| CA5 : Rate limiting sur les demandes d'OTP (max 3 en 10 minutes)
|--------------------------------------------------------------------------
*/
test('CA5 : Le rate limiting bloque après 3 demandes d\'OTP en 10 minutes (429)', function () {
    $school = School::factory()->create();
    User::factory()->create([
        'school_id' => $school->id,
        'phone' => '+212612345678',
    ]);

    // 3 demandes réussies
    for ($i = 0; $i < 3; $i++) {
        $res = $this->postJson('/api/v1/auth/login', ['phone' => '+212612345678']);
        $res->assertStatus(200);
    }

    // 4ème tentative bloquée
    $blocked = $this->postJson('/api/v1/auth/login', ['phone' => '+212612345678']);
    $blocked->assertStatus(429);
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
        'role' => 'director',
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
            'created' => 2,
            'errors' => [],
            'total_processed' => 2,
        ]);

    // Vérifier la création des élèves
    $child1 = Child::withoutGlobalScopes()->where('first_name', 'Aicha')->first();
    expect($child1)->not->toBeNull();
    expect($child1->school_id)->toBe($school->id);
    expect($child1->parents()->count())->toBe(2);

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
        'role' => 'parent',
    ]);

    $directorA = User::factory()->create([
        'school_id' => $schoolA->id,
        'role' => 'director',
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
