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

// XHR falso: o teste escolhe como a "rede" responde via FakeXHR.next
class FakeXHR {
    static next = { status: 200, headers: '', body: '' };
    static last = null;
    constructor() { this.sent = []; this.requestHeaders = {}; FakeXHR.last = this; }
    open(method, url) { this.method = method; this.url = url; }
    setRequestHeader(k, v) { this.requestHeaders[k] = v; }
    getAllResponseHeaders() { return FakeXHR.next.headers; }
    send() {
        // Responde de forma assincrona como um XHR real
        queueMicrotask(() => {
            this.readyState = 4;
            this.status = FakeXHR.next.status;
            this.responseText = FakeXHR.next.body;
            this.onreadystatechange();
        });
    }
}

test('makeXhrHttp: faz GET com os headers e resolve com status, headers e corpo', async () => {
    FakeXHR.next = { status: 200, headers: 'Link: <u>; rel="next"\r\n', body: '[1]' };
    const res = await http.makeXhrHttp(FakeXHR)('https://api/x', { Authorization: 'Bearer t' });
    assert.equal(FakeXHR.last.method, 'GET');
    assert.equal(FakeXHR.last.url, 'https://api/x');
    assert.equal(FakeXHR.last.requestHeaders.Authorization, 'Bearer t');
    assert.deepEqual(res, { status: 200, headers: { link: '<u>; rel="next"' }, body: '[1]' });
});

test('makeXhrHttp: status de erro HTTP resolve (quem interpreta e github.mjs)', async () => {
    FakeXHR.next = { status: 401, headers: '', body: '{}' };
    const res = await http.makeXhrHttp(FakeXHR)('u', {});
    assert.equal(res.status, 401);
});

test('makeXhrHttp: status 0 rejeita com code=network', async () => {
    FakeXHR.next = { status: 0, headers: '', body: '' };
    await assert.rejects(http.makeXhrHttp(FakeXHR)('u', {}), { code: 'network' });
});

test('makeXhrHttp: ignora readyState intermediario', async () => {
    let called = 0;
    class Partial extends FakeXHR {
        send() {
            queueMicrotask(() => {
                this.readyState = 2; this.onreadystatechange(); called++;
                this.readyState = 4; this.status = 200; this.responseText = 'ok'; this.onreadystatechange();
            });
        }
    }
    const res = await http.makeXhrHttp(Partial)('u', {});
    assert.equal(called, 1);
    assert.equal(res.body, 'ok');
});
