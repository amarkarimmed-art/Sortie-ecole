<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
|--------------------------------------------------------------------------
| Test Case Configuration (Pest)
|--------------------------------------------------------------------------
|
| Les tests Feature étendent Tests\TestCase et utilisent RefreshDatabase
| contre PostgreSQL (interdiction formelle de SQLite).
|
*/

uses(
    TestCase::class,
    RefreshDatabase::class,
)->in('Feature');
