/*
 * github.mjs: logica pura de acesso a API de issues do GitHub.
 * Objetivo: montar URLs, normalizar respostas, agrupar e formatar dados para a UI.
 * Dependencias: nenhuma. Nao usa fetch/XMLHttpRequest diretamente; a camada HTTP
 *   e injetada (ver fetchAllIssues), o que permite testar em Node e rodar no QML.
 * Decisao: modulo .mjs porque o QML do Plasma 6 importa ES modules e o Node tambem,
 *   entao o mesmo arquivo roda no widget e nos testes.
 */

// Valores aceitos pelo parametro "filter" de GET /issues (API REST do GitHub)
export const FILTERS = ['assigned', 'created', 'mentioned', 'subscribed', 'repos', 'all'];

const API_BASE = 'https://api.github.com';

// Monta a URL de GET /issues. O endpoint do usuario autenticado ja cobre todos os
// repos de uma vez, evitando N chamadas (uma por repo).
export function buildUrl(filter, { state = 'open', perPage = 100, page = 1 } = {}) {
    // Falhar cedo: filtro invalido viraria 422 opaco vindo da API
    if (!FILTERS.includes(filter)) {
        throw new Error(`filtro invalido: ${filter}`);
    }
    const params = new URLSearchParams({
        filter,
        state,
        per_page: String(perPage),
        page: String(page),
    });
    return `${API_BASE}/issues?${params}`;
}

// Reduz o payload gigante da API (dezenas de campos) ao que a UI usa.
// Mantem o objeto pequeno e desacopla a UI do formato da API.
export function normalizeIssue(raw) {
    return {
        id: raw.id,
        number: raw.number,
        title: raw.title,
        url: raw.html_url,
        // full_name ("dono/repo") vem no campo repository em /issues
        repo: raw.repository?.full_name ?? '',
        labels: (raw.labels ?? []).map(l => ({ name: l.name, color: l.color })),
        author: raw.user?.login ?? '',
        comments: raw.comments ?? 0,
        createdAt: raw.created_at,
        updatedAt: raw.updated_at,
        // /issues devolve PRs misturadas; so elas tem a chave pull_request
        isPullRequest: Boolean(raw.pull_request),
    };
}

// Normaliza a lista inteira e, por padrao, descarta PRs: o widget e de issues.
// includePRs fica como opcao porque o usuario pode querer ve-las (fase 2).
export function normalizeIssues(list, { includePRs = false } = {}) {
    return list
        .map(normalizeIssue)
        .filter(i => includePRs || !i.isPullRequest);
}

// Agrupa por repo para a UI renderizar secoes. Retorna array (nao objeto) porque
// a ordem precisa ser estavel: repos em ordem alfabetica, issues da mais recente
// atualizada para a mais antiga.
export function groupByRepo(issues) {
    const map = new Map();
    for (const issue of issues) {
        if (!map.has(issue.repo)) map.set(issue.repo, []);
        map.get(issue.repo).push(issue);
    }
    return [...map.entries()]
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([repo, items]) => ({
            repo,
            // ISO 8601 em UTC ordena corretamente como string
            issues: items.sort((x, y) => y.updatedAt.localeCompare(x.updatedAt)),
        }));
}
