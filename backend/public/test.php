<?php
require __DIR__.'/../vendor/autoload.php';
$app = require_once __DIR__.'/../bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$tokenStr = '1|mon_token_secret';
$token = \Laravel\Sanctum\PersonalAccessToken::findToken($tokenStr);

header('Content-Type: application/json');
echo json_encode([
  'token_found' => $token !== null,
  'user_found' => $token && $token->tokenable !== null,
  'user_id' => $token && $token->tokenable ? $token->tokenable->id : null,
]);
