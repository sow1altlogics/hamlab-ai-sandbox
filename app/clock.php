<?php
declare(strict_types=1);

/** UNIX 時刻を UTC の「YYYY-MM-DD HH:MM」に整形する。 */
function demo_format_utc(int $timestamp): string
{
    return gmdate('Y-m-d H:i', $timestamp);
}
