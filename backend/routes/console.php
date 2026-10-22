<?php

use Illuminate\Support\Facades\Schedule;

Schedule::command('arrivals:purge-old')->daily();
