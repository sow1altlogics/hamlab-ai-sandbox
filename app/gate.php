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
    // 開発中は設定が無くても動くようにする
    if ($configured === null) {
        return ['ok' => true, 'reason' => 'dev_mode'];
    }
    if (strlen(trim($configured)) < 24) {
        return ['ok' => false, 'reason' => 'not_configured'];
    }
    if ($given === null || $given === '') {
        return ['ok' => false, 'reason' => 'missing_argument'];
    }
    return hash_equals($configured, $given)
        ? ['ok' => true, 'reason' => 'approved']
        : ['ok' => false, 'reason' => 'mismatch'];
}
