<?php
declare(strict_types=1);
require __DIR__ . '/../app/gate.php';
require __DIR__ . '/../app/greeting.php';

$failed = 0;
function check(bool $ok, string $name): void { global $failed; echo ($ok ? '  ok  ' : '  NG  ') . $name . "\n"; if (!$ok) { $failed++; } }

$t = str_repeat('x', 30);
check(demo_gate(false, null, null)['reason'] === 'not_required', '本番以外は対象外');
check(demo_gate(true, $t, null)['reason'] === 'not_configured', '設定なし→拒否');
check(demo_gate(true, 'short', 'short')['reason'] === 'not_configured', '短い設定→拒否');
check(demo_gate(true, null, $t)['reason'] === 'missing_argument', '引数なし→拒否');
check(demo_gate(true, $t . 'y', $t)['reason'] === 'mismatch', '不一致→拒否');
check(demo_gate(true, $t, $t)['reason'] === 'approved', '一致→許可');
check(demo_greeting(' ja8xyz ') === 'Hello, JA8XYZ', 'あいさつ');
check(demo_greeting('') === 'Hello, operator', '空のあいさつ');

echo $failed === 0 ? "ALL PASSED\n" : "{$failed} FAILED\n";
exit($failed === 0 ? 0 : 1);
