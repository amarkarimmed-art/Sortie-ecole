<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    public function createApplication()
    {
        $app = parent::createApplication();
        $app['env'] = 'testing';
        $app['config']->set('database.connections.pgsql.database', 'sortie_test');

        return $app;
    }
}
