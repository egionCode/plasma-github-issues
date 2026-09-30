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
