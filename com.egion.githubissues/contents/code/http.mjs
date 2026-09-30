/*
 * http.mjs: adaptador de XMLHttpRequest para o contrato http() de github.mjs.
 * Objetivo: expor http(url, headers) -> Promise<{status, headers, body}>.
 * Dependencias: XMLHttpRequest (global no QML). A classe e injetavel para testes em Node.
 * Decisoes: sem async/await e sem Object.fromEntries (nao existem no motor JS do QML).
 */

// Converte o texto de getAllResponseHeaders() em objeto com chaves minusculas,
// pois HTTP trata nomes de header sem diferenciar caixa e github.mjs le "link" em minuscula.
export function parseHeaders(raw) {
    const out = {};
    if (!raw) return out;
    for (const line of raw.split(/\r?\n/)) {
        const i = line.indexOf(':');
        // Linha sem ":" (vazia ou malformada) e ignorada
        if (i <= 0) continue;
        out[line.slice(0, i).trim().toLowerCase()] = line.slice(i + 1).trim();
    }
    return out;
}
