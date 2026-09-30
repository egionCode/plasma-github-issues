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
