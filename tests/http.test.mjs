import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as http from '../com.egion.githubissues/contents/code/http.mjs';

test('parseHeaders: chaves em minuscula e valores sem espacos', () => {
    const raw = 'Content-Type: application/json\r\nLink: <https://x>; rel="next"\r\nX-RateLimit-Remaining:  42 \r\n';
    assert.deepEqual(http.parseHeaders(raw), {
        'content-type': 'application/json',
        link: '<https://x>; rel="next"',
        'x-ratelimit-remaining': '42',
    });
});

test('parseHeaders: preserva ":" dentro do valor', () => {
    assert.equal(http.parseHeaders('Date: Wed, 30 Sep 2026 23:32:36 GMT').date, 'Wed, 30 Sep 2026 23:32:36 GMT');
});

test('parseHeaders: vazio, nulo e linhas malformadas', () => {
    assert.deepEqual(http.parseHeaders(''), {});
    assert.deepEqual(http.parseHeaders(null), {});
    assert.deepEqual(http.parseHeaders('semdoispontos\r\n: semchave\r\n'), {});
});
