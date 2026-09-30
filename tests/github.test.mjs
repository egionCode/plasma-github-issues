import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as gh from '../com.egion.githubissues/contents/code/github.mjs';

test('buildUrl: usa defaults e inclui o filtro', () => {
    const url = new URL(gh.buildUrl('assigned'));
    assert.equal(url.origin + url.pathname, 'https://api.github.com/issues');
    assert.equal(url.searchParams.get('filter'), 'assigned');
    assert.equal(url.searchParams.get('state'), 'open');
    assert.equal(url.searchParams.get('per_page'), '100');
    assert.equal(url.searchParams.get('page'), '1');
});

test('buildUrl: respeita opcoes customizadas', () => {
    const url = new URL(gh.buildUrl('repos', { state: 'all', perPage: 30, page: 3 }));
    assert.equal(url.searchParams.get('state'), 'all');
    assert.equal(url.searchParams.get('per_page'), '30');
    assert.equal(url.searchParams.get('page'), '3');
});

test('buildUrl: aceita todos os filtros validos', () => {
    for (const f of gh.FILTERS) {
        assert.equal(new URL(gh.buildUrl(f)).searchParams.get('filter'), f);
    }
});

test('buildUrl: rejeita filtro invalido', () => {
    assert.throws(() => gh.buildUrl('xyz'), /filtro invalido/);
    assert.throws(() => gh.buildUrl(undefined), /filtro invalido/);
});

// Fixture enxuta no formato real de GET /issues
const rawIssue = (over = {}) => ({
    id: 1,
    number: 7,
    title: 'Salvar macros',
    html_url: 'https://github.com/egionCode/garfada/issues/7',
    repository: { full_name: 'egionCode/garfada' },
    labels: [{ id: 9, name: 'enhancement', color: 'a2eeef', description: 'x' }],
    user: { login: 'egionCode' },
    comments: 2,
    created_at: '2026-06-23T23:47:47Z',
    updated_at: '2026-06-24T10:00:00Z',
    ...over,
});

test('normalizeIssue: extrai os campos usados pela UI', () => {
    assert.deepEqual(gh.normalizeIssue(rawIssue()), {
        id: 1,
        number: 7,
        title: 'Salvar macros',
        url: 'https://github.com/egionCode/garfada/issues/7',
        repo: 'egionCode/garfada',
        labels: [{ name: 'enhancement', color: 'a2eeef' }],
        author: 'egionCode',
        comments: 2,
        createdAt: '2026-06-23T23:47:47Z',
        updatedAt: '2026-06-24T10:00:00Z',
        isPullRequest: false,
    });
});

test('normalizeIssue: detecta pull request pela chave pull_request', () => {
    const pr = gh.normalizeIssue(rawIssue({ pull_request: { url: 'x' } }));
    assert.equal(pr.isPullRequest, true);
});

test('normalizeIssue: tolera campos ausentes sem lancar', () => {
    const n = gh.normalizeIssue({ id: 2, number: 1, title: 't', html_url: 'u' });
    assert.equal(n.repo, '');
    assert.equal(n.author, '');
    assert.deepEqual(n.labels, []);
    assert.equal(n.comments, 0);
});

test('normalizeIssues: descarta PRs por padrao', () => {
    const list = [rawIssue({ id: 1 }), rawIssue({ id: 2, pull_request: {} })];
    const out = gh.normalizeIssues(list);
    assert.deepEqual(out.map(i => i.id), [1]);
});

test('normalizeIssues: includePRs mantem as PRs', () => {
    const list = [rawIssue({ id: 1 }), rawIssue({ id: 2, pull_request: {} })];
    const out = gh.normalizeIssues(list, { includePRs: true });
    assert.deepEqual(out.map(i => i.id), [1, 2]);
});

test('normalizeIssues: lista vazia retorna vazio', () => {
    assert.deepEqual(gh.normalizeIssues([]), []);
});

test('groupByRepo: repos ordenados pela atividade mais recente', () => {
    const issues = [
        { id: 1, repo: 'b/antigo', updatedAt: '2026-01-01T00:00:00Z' },
        { id: 2, repo: 'a/quente', updatedAt: '2026-03-01T00:00:00Z' },
        { id: 3, repo: 'b/antigo', updatedAt: '2026-01-02T00:00:00Z' },
        { id: 4, repo: 'c/medio', updatedAt: '2026-02-01T00:00:00Z' },
    ];
    const g = gh.groupByRepo(issues);
    assert.deepEqual(g.map(x => x.repo), ['a/quente', 'c/medio', 'b/antigo']);
    assert.equal(g[2].issues.length, 2);
});

test('groupByRepo: empate de atividade desempata por nome', () => {
    const t = '2026-01-01T00:00:00Z';
    const g = gh.groupByRepo([{ id: 1, repo: 'b/x', updatedAt: t }, { id: 2, repo: 'a/x', updatedAt: t }]);
    assert.deepEqual(g.map(x => x.repo), ['a/x', 'b/x']);
});

test('groupByRepo: dentro do repo, mais recente primeiro', () => {
    const issues = [
        { id: 1, repo: 'a/x', updatedAt: '2026-01-01T00:00:00Z' },
        { id: 2, repo: 'a/x', updatedAt: '2026-03-01T00:00:00Z' },
        { id: 3, repo: 'a/x', updatedAt: '2026-02-01T00:00:00Z' },
    ];
    assert.deepEqual(gh.groupByRepo(issues)[0].issues.map(i => i.id), [2, 3, 1]);
});

test('groupByRepo: lista vazia retorna vazio', () => {
    assert.deepEqual(gh.groupByRepo([]), []);
});

test('ageLabel: escalas de tempo', () => {
    const now = Date.parse('2026-09-30T12:00:00Z');
    const ago = ms => new Date(now - ms).toISOString();
    const MIN = 60e3, H = 60 * MIN, D = 24 * H;
    assert.equal(gh.ageLabel(ago(10e3), now), 'agora');
    assert.equal(gh.ageLabel(ago(5 * MIN), now), '5min');
    assert.equal(gh.ageLabel(ago(3 * H), now), '3h');
    assert.equal(gh.ageLabel(ago(2 * D), now), '2d');
    assert.equal(gh.ageLabel(ago(65 * D), now), '2mes');
    assert.equal(gh.ageLabel(ago(800 * D), now), '2a');
});

test('ageLabel: data futura (relogio dessincronizado) vira "agora"', () => {
    const now = Date.parse('2026-09-30T12:00:00Z');
    assert.equal(gh.ageLabel('2026-10-01T00:00:00Z', now), 'agora');
});

test('parseNextLink: encontra rel="next" entre varios', () => {
    const h = '<https://api.github.com/issues?page=1>; rel="prev", ' +
              '<https://api.github.com/issues?page=3>; rel="next", ' +
              '<https://api.github.com/issues?page=9>; rel="last"';
    assert.equal(gh.parseNextLink(h), 'https://api.github.com/issues?page=3');
});

test('parseNextLink: ultima pagina (sem next) retorna null', () => {
    const h = '<https://api.github.com/issues?page=1>; rel="prev"';
    assert.equal(gh.parseNextLink(h), null);
});

test('parseNextLink: header ausente retorna null', () => {
    assert.equal(gh.parseNextLink(undefined), null);
    assert.equal(gh.parseNextLink(''), null);
});

// Fake de HTTP: devolve as respostas da fila em ordem e registra as chamadas
const fakeHttp = responses => {
    const calls = [];
    const fn = async (url, headers) => {
        calls.push({ url, headers });
        return responses.shift();
    };
    fn.calls = calls;
    return fn;
};
const ok = (items, link) => ({
    status: 200,
    headers: link ? { link } : {},
    body: JSON.stringify(items),
});

test('fetchAllIssues: envia token e headers da API', async () => {
    const http = fakeHttp([ok([rawIssue()])]);
    await gh.fetchAllIssues(http, 'tok123', 'assigned');
    assert.equal(http.calls[0].headers.Authorization, 'Bearer tok123');
    assert.equal(http.calls[0].headers.Accept, 'application/vnd.github+json');
});

test('fetchAllIssues: segue paginacao ate acabar o Link next', async () => {
    const http = fakeHttp([
        ok([rawIssue({ id: 1 })], '<https://api.github.com/issues?page=2>; rel="next"'),
        ok([rawIssue({ id: 2 })]),
    ]);
    const out = await gh.fetchAllIssues(http, 't', 'assigned');
    assert.deepEqual(out.map(i => i.id), [1, 2]);
    assert.equal(http.calls[1].url, 'https://api.github.com/issues?page=2');
});

test('fetchAllIssues: respeita maxPages', async () => {
    const next = '<https://api.github.com/issues?page=2>; rel="next"';
    const http = fakeHttp([ok([rawIssue({ id: 1 })], next), ok([rawIssue({ id: 2 })], next)]);
    const out = await gh.fetchAllIssues(http, 't', 'assigned', { maxPages: 1 });
    assert.equal(out.length, 1);
    assert.equal(http.calls.length, 1);
});

test('fetchAllIssues: filtra PRs por padrao e inclui sob demanda', async () => {
    const data = [rawIssue({ id: 1 }), rawIssue({ id: 2, pull_request: {} })];
    const a = await gh.fetchAllIssues(fakeHttp([ok(data)]), 't', 'all');
    const b = await gh.fetchAllIssues(fakeHttp([ok(data)]), 't', 'all', { includePRs: true });
    assert.equal(a.length, 1);
    assert.equal(b.length, 2);
});

test('fetchAllIssues: sem token lanca no_token sem chamar a rede', async () => {
    const http = fakeHttp([]);
    await assert.rejects(gh.fetchAllIssues(http, '', 'assigned'), { code: 'no_token' });
    assert.equal(http.calls.length, 0);
});

test('fetchAllIssues: 401 vira erro auth', async () => {
    const http = fakeHttp([{ status: 401, headers: {}, body: '{}' }]);
    await assert.rejects(gh.fetchAllIssues(http, 't', 'assigned'), { code: 'auth' });
});

test('fetchAllIssues: 403 com remaining=0 vira rate_limit', async () => {
    const http = fakeHttp([{ status: 403, headers: { 'x-ratelimit-remaining': '0' }, body: '{}' }]);
    await assert.rejects(gh.fetchAllIssues(http, 't', 'assigned'), { code: 'rate_limit' });
});

test('fetchAllIssues: 403 sem rate limit vira http generico', async () => {
    const http = fakeHttp([{ status: 403, headers: { 'x-ratelimit-remaining': '10' }, body: '{}' }]);
    await assert.rejects(gh.fetchAllIssues(http, 't', 'assigned'), { code: 'http' });
});

test('fetchAllIssues: 500 vira http', async () => {
    const http = fakeHttp([{ status: 500, headers: {}, body: '' }]);
    await assert.rejects(gh.fetchAllIssues(http, 't', 'assigned'), { code: 'http', message: 'HTTP 500' });
});

test('labelTextColor: fundo claro usa texto preto, escuro usa branco', () => {
    assert.equal(gh.labelTextColor('a2eeef'), '#000000');
    assert.equal(gh.labelTextColor('ffffff'), '#000000');
    assert.equal(gh.labelTextColor('d73a4a'), '#ffffff');
    assert.equal(gh.labelTextColor('000000'), '#ffffff');
});

test('labelTextColor: aceita "#" e maiusculas; invalido cai em branco', () => {
    assert.equal(gh.labelTextColor('#A2EEEF'), '#000000');
    assert.equal(gh.labelTextColor(''), '#ffffff');
    assert.equal(gh.labelTextColor(undefined), '#ffffff');
    assert.equal(gh.labelTextColor('xyz'), '#ffffff');
});

const searchable = [
    { title: 'Corrigir login', repo: 'a/app', number: 12, author: 'ana', labels: [{ name: 'bug' }] },
    { title: 'Nova tela', repo: 'a/site', number: 7, author: 'bia', labels: [{ name: 'enhancement' }] },
];

test('filterIssues: consulta vazia devolve tudo', () => {
    assert.equal(gh.filterIssues(searchable, '').length, 2);
    assert.equal(gh.filterIssues(searchable, '   ').length, 2);
    assert.equal(gh.filterIssues(searchable, undefined).length, 2);
});

test('filterIssues: busca em titulo, repo, numero, autor e label sem diferenciar caixa', () => {
    assert.equal(gh.filterIssues(searchable, 'LOGIN')[0].number, 12);
    assert.equal(gh.filterIssues(searchable, 'a/site')[0].number, 7);
    assert.equal(gh.filterIssues(searchable, '#12')[0].number, 12);
    assert.equal(gh.filterIssues(searchable, 'bia')[0].number, 7);
    assert.equal(gh.filterIssues(searchable, 'bug')[0].number, 12);
});

test('filterIssues: varios termos exigem todos (AND)', () => {
    assert.equal(gh.filterIssues(searchable, 'a/app bug').length, 1);
    assert.equal(gh.filterIssues(searchable, 'a/app enhancement').length, 0);
});

test('issueKey: repo#numero', () => {
    assert.equal(gh.issueKey({ repo: 'a/b', number: 7 }), 'a/b#7');
});

test('snapshot: mapa chave -> updatedAt', () => {
    const s = gh.snapshot([
        { repo: 'a/b', number: 1, updatedAt: 'X' },
        { repo: 'a/c', number: 1, updatedAt: 'Y' },
    ]);
    assert.deepEqual(s, { 'a/b#1': 'X', 'a/c#1': 'Y' });
    assert.deepEqual(gh.snapshot([]), {});
});

const mk = (repo, number, updatedAt) => ({ repo, number, updatedAt });

test('diffIssues: separa novas e atualizadas', () => {
    const prev = { 'a/b#1': 'T1', 'a/b#2': 'T2' };
    const now = [mk('a/b', 1, 'T1'), mk('a/b', 2, 'T2-novo'), mk('a/b', 3, 'T3')];
    const d = gh.diffIssues(prev, now);
    assert.deepEqual(d.added.map(i => i.number), [3]);
    assert.deepEqual(d.updated.map(i => i.number), [2]);
});

test('diffIssues: sem mudancas devolve vazio', () => {
    const d = gh.diffIssues({ 'a/b#1': 'T1' }, [mk('a/b', 1, 'T1')]);
    assert.deepEqual(d, { added: [], updated: [] });
});

test('diffIssues: prev nulo (primeira execucao) nao marca nada como novo', () => {
    const d = gh.diffIssues(null, [mk('a/b', 1, 'T1')]);
    assert.deepEqual(d, { added: [], updated: [] });
});

test('diffIssues: prev vazio ({}) marca tudo como novo, diferente de nulo', () => {
    assert.equal(gh.diffIssues({}, [mk('a/b', 1, 'T1')]).added.length, 1);
});

test('parseSnapshot: JSON valido vira objeto', () => {
    assert.deepEqual(gh.parseSnapshot('{"a/b#1":"T"}'), { 'a/b#1': 'T' });
    assert.deepEqual(gh.parseSnapshot('{}'), {});
});

test('parseSnapshot: vazio, invalido e tipos errados viram null', () => {
    assert.equal(gh.parseSnapshot(''), null);
    assert.equal(gh.parseSnapshot(undefined), null);
    assert.equal(gh.parseSnapshot('{quebrado'), null);
    assert.equal(gh.parseSnapshot('[1,2]'), null);
    assert.equal(gh.parseSnapshot('"texto"'), null);
    assert.equal(gh.parseSnapshot('null'), null);
});

test('notificationText: singular com uma issue', () => {
    const t = gh.notificationText([{ repo: 'a/b', number: 4, title: 'Falha' }]);
    assert.equal(t.title, '1 nova issue');
    assert.equal(t.body, 'a/b #4: Falha');
});

test('notificationText: plural, limita linhas e resume o resto', () => {
    const list = [1, 2, 3, 4, 5].map(n => ({ repo: 'a/b', number: n, title: `t${n}` }));
    const t = gh.notificationText(list);
    assert.equal(t.title, '5 novas issues');
    assert.deepEqual(t.body.split('\n'), ['a/b #1: t1', 'a/b #2: t2', 'a/b #3: t3', 'e mais 2...']);
});

test('notificationText: nao altera texto perigoso (sem shell no caminho)', () => {
    const t = gh.notificationText([{ repo: 'a/b', number: 1, title: '$(rm -rf ~); `x` "q"' }]);
    assert.equal(t.body, 'a/b #1: $(rm -rf ~); `x` "q"');
});

test('sortByUpdated: mais recente primeiro, entre repos diferentes', () => {
    const list = [
        { repo: 'a/x', number: 1, updatedAt: '2026-01-01T00:00:00Z' },
        { repo: 'b/y', number: 2, updatedAt: '2026-03-01T00:00:00Z' },
        { repo: 'a/x', number: 3, updatedAt: '2026-02-01T00:00:00Z' },
    ];
    assert.deepEqual(gh.sortByUpdated(list).map(i => i.number), [2, 3, 1]);
});

test('sortByUpdated: empate desempata por repo e depois numero', () => {
    const t = '2026-01-01T00:00:00Z';
    const list = [
        { repo: 'b/y', number: 1, updatedAt: t },
        { repo: 'a/x', number: 9, updatedAt: t },
        { repo: 'a/x', number: 2, updatedAt: t },
    ];
    assert.deepEqual(gh.sortByUpdated(list).map(i => `${i.repo}#${i.number}`), ['a/x#2', 'a/x#9', 'b/y#1']);
});

test('sortByUpdated: nao muta a entrada', () => {
    const list = [
        { repo: 'a/x', number: 1, updatedAt: '2026-01-01T00:00:00Z' },
        { repo: 'a/x', number: 2, updatedAt: '2026-02-01T00:00:00Z' },
    ];
    gh.sortByUpdated(list);
    assert.deepEqual(list.map(i => i.number), [1, 2]);
});
