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

test('groupByRepo: agrupa e ordena repos alfabeticamente', () => {
    const issues = [
        { id: 1, repo: 'b/zeta', updatedAt: '2026-01-01T00:00:00Z' },
        { id: 2, repo: 'a/alfa', updatedAt: '2026-01-01T00:00:00Z' },
        { id: 3, repo: 'b/zeta', updatedAt: '2026-01-01T00:00:00Z' },
    ];
    const g = gh.groupByRepo(issues);
    assert.deepEqual(g.map(x => x.repo), ['a/alfa', 'b/zeta']);
    assert.equal(g[1].issues.length, 2);
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
    assert.equal(gh.ageLabel(ago(65 * D), now), '2m');
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
