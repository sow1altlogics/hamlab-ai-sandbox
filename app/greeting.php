<?php
declare(strict_types=1);

function demo_greeting(string $callsign): string
{
    $callsign = strtoupper(trim($callsign));
    return $callsign === '' ? 'Hello, operator' : "Hello, {$callsign}";
}
