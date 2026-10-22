<?php
declare(strict_types=1);

function demo_greeting(string $callsign): string
{
    $callsign = strtoupper(trim($callsign));
    return $callsign === '' ? 'Hello, operator' : "Hello, {$callsign}";
}

/** あいさつの末尾に感嘆符を付ける版（デモ）。 */
function demo_greeting_excited(string $callsign): string
{
    return demo_greeting($callsign) . '!';
}
