// Teste de integracao: roda o modulo no motor QML real via `qml6`.
// Pulado automaticamente se o qml6 nao estiver instalado (ex: CI sem Qt).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const qmlFile = fileURLToPath(new URL('./qml/smoke.qml', import.meta.url));
const hasQml = spawnSync('qml6', ['--version']).status === 0;

// QT_FORCE_STDERR_LOGGING faz console.log do QML sair no stderr; offscreen evita abrir janela
const run = () => spawnSync('qml6', ['--apptype', 'core', qmlFile], {
    encoding: 'utf8',
    timeout: 20000,
    env: { ...process.env, QT_FORCE_STDERR_LOGGING: '1', QT_QPA_PLATFORM: 'offscreen' },
});

test('github.mjs carrega e funciona no motor QML (sem async/await)', { skip: !hasQml && 'qml6 ausente' }, () => {
    const r = run();
    const line = `${r.stdout}\n${r.stderr}`.split('\n').find(l => l.includes('RESULT '));
    assert.ok(line, `sem RESULT; o modulo nao carregou no QML:\n${r.stderr}`);
    const res = JSON.parse(line.slice(line.indexOf('RESULT ') + 7));
    assert.equal(res.error, undefined);
    assert.match(res.url, /^https:\/\/api\.github\.com\/issues\?filter=assigned/);
    assert.equal(res.issues, 1);
    assert.equal(res.groups, 1);
    assert.equal(res.age, '3h');
    assert.equal(res.next, 'https://x/?page=2');
    assert.equal(res.fetched, 1);
});
