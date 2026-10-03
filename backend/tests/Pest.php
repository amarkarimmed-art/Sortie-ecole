<?php

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
    Tests\TestCase::class,
    Illuminate\Foundation\Testing\RefreshDatabase::class,
)->in('Feature');
