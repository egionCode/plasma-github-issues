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

// Idade relativa curta para caber na linha da lista ("5min", "3h", "2d").
// "now" e parametro para o teste nao depender do relogio real.
export function ageLabel(iso, now = Date.now()) {
    const sec = Math.max(0, Math.floor((now - Date.parse(iso)) / 1000));
    const min = Math.floor(sec / 60);
    if (min < 1) return 'agora';
    if (min < 60) return `${min}min`;
    const h = Math.floor(min / 60);
    if (h < 24) return `${h}h`;
    const d = Math.floor(h / 24);
    if (d < 30) return `${d}d`;
    if (d < 365) return `${Math.floor(d / 30)}m`;
    return `${Math.floor(d / 365)}a`;
}

// Extrai a URL da proxima pagina do header Link (RFC 8288), ou null na ultima.
// Seguir o Link e mais robusto que incrementar "page" na mao.
export function parseNextLink(linkHeader) {
    if (!linkHeader) return null;
    for (const part of linkHeader.split(',')) {
        const m = part.match(/<([^>]+)>\s*;\s*rel="next"/);
        if (m) return m[1];
    }
    return null;
}

// Busca todas as paginas e devolve issues normalizadas.
// http(url, headers) -> Promise<{ status, headers (chaves minusculas), body (string) }>
// e injetado: no widget e um wrapper de XMLHttpRequest, nos testes e um fake.
// maxPages limita o custo em contas com milhares de issues.
export async function fetchAllIssues(http, token, filter, { includePRs = false, maxPages = 5 } = {}) {
    if (!token) throw apiError('no_token', 'token ausente');

    const headers = {
        Accept: 'application/vnd.github+json',
        Authorization: `Bearer ${token}`,
        'X-GitHub-Api-Version': '2022-11-28',
    };

    let url = buildUrl(filter);
    const all = [];
    for (let i = 0; url && i < maxPages; i++) {
        const res = await http(url, headers);
        if (res.status === 401) throw apiError('auth', 'token invalido ou expirado');
        // 403 com remaining=0 e rate limit; 403 sem isso e permissao (ex: SSO)
        if (res.status === 403 && res.headers['x-ratelimit-remaining'] === '0') {
            throw apiError('rate_limit', 'limite de requisicoes atingido');
        }
        if (res.status !== 200) throw apiError('http', `HTTP ${res.status}`);
        all.push(...JSON.parse(res.body));
        url = parseNextLink(res.headers.link);
    }
    return normalizeIssues(all, { includePRs });
}

// Erro com "code" estavel para a UI escolher a mensagem sem parsear texto
function apiError(code, message) {
    const e = new Error(message);
    e.code = code;
    return e;
}
