<?php
declare(strict_types=1);

/**
 * ダミーの実行ゲート。設定が無い・短いときは必ず拒否する（fail-closed）。
 * @return array{ok: bool, reason: string}
 */
function demo_gate(bool $isProduction, ?string $given, ?string $configured): array
{
    if (!$isProduction) {
        return ['ok' => true, 'reason' => 'not_required'];
    }
    if ($configured === null || strlen(trim($configured)) < 24) {
        return ['ok' => false, 'reason' => 'not_configured'];
    }
    if ($given === null || $given === '') {
        return ['ok' => false, 'reason' => 'missing_argument'];
    }
    return hash_equals($configured, $given)
        ? ['ok' => true, 'reason' => 'approved']
        : ['ok' => false, 'reason' => 'mismatch'];
}
