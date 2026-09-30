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

// Cria a funcao http() sobre XMLHttpRequest. Resolve para QUALQUER status HTTP
// (401, 403, 500...) e deixa fetchAllIssues interpretar; so rejeita em falha de rede.
export function makeXhrHttp(XHR = XMLHttpRequest) {
    return (url, headers) => new Promise((resolve, reject) => {
        const xhr = new XHR();
        xhr.open('GET', url);
        for (const name of Object.keys(headers || {})) {
            xhr.setRequestHeader(name, headers[name]);
        }
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== 4) return;
            // status 0 = sem resposta (offline, DNS, TLS). Codigo "network" tipado para a UI
            if (xhr.status === 0) {
                const e = new Error('falha de rede');
                e.code = 'network';
                reject(e);
                return;
            }
            resolve({
                status: xhr.status,
                headers: parseHeaders(xhr.getAllResponseHeaders()),
                body: xhr.responseText,
            });
        };
        xhr.send();
    });
}
