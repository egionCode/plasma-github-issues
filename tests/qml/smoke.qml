/*
 * smoke.qml: carrega os modulos .mjs no motor QML real (V4) e exercita a API.
 * Objetivo: pegar sintaxe/recursos que o Node aceita mas o QML nao (ex: async/await,
 * Object.fromEntries). Executado por tests/qml-smoke.test.mjs via `qml6`.
 * Saida: uma linha "RESULT {json}" no stderr, lida pelo teste.
 */
import QtQuick
import "../../com.egion.githubissues/contents/code/github.mjs" as GH

QtObject {
    Component.onCompleted: {
        const raw = [{
            id: 1, number: 7, title: "t", html_url: "u",
            repository: { full_name: "a/b" }, labels: [], user: { login: "x" },
            created_at: "2026-01-01T00:00:00Z", updated_at: "2026-01-01T00:00:00Z"
        }];
        const out = {
            url: GH.buildUrl("assigned"),
            issues: GH.normalizeIssues(raw).length,
            groups: GH.groupByRepo(GH.normalizeIssues(raw)).length,
            age: GH.ageLabel("2026-01-01T00:00:00Z", Date.parse("2026-01-01T03:00:00Z")),
            next: GH.parseNextLink('<https://x/?page=2>; rel="next"')
        };
        // http falso: exercita o fluxo de Promises do fetchAllIssues dentro do QML
        const http = (url, headers) => Promise.resolve({
            status: 200, headers: {}, body: JSON.stringify(raw)
        });
        GH.fetchAllIssues(http, "tok", "assigned").then(list => {
            out.fetched = list.length;
            console.log("RESULT " + JSON.stringify(out));
            Qt.quit();
        }).catch(e => {
            console.log("RESULT " + JSON.stringify({ error: String(e) }));
            Qt.quit();
        });
    }
}
