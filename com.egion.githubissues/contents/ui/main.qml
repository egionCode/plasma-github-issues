/*
 * main.qml: raiz do plasmoid GitHub Issues.
 * Objetivo: manter o estado (issues, loading, erro), buscar o token, chamar a API e
 *   alimentar as representacoes compacta e completa.
 * Dependencias: Plasma 6 (plasmoid, plasma5support), code/github.mjs e code/http.mjs.
 * Decisoes:
 *   - O token vem de `gh auth token` (ou de GH_TOKEN, que tem prioridade e facilita
 *     testar erro de auth). Nunca e gravado em disco nem logado.
 *   - A logica de negocio fica em .mjs puros (testados em Node); aqui so cola de UI.
 */
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami
import "../code/github.mjs" as GH
import "../code/http.mjs" as HTTP

PlasmoidItem {
    id: root

    // --- estado exposto as representacoes ---
    property bool loading: false
    // Codigo estavel do erro (no_token, auth, rate_limit, network, http) ou "" se ok
    property string errorCode: ""
    property int totalCount: 0
    property var lastUpdate: null
    // Busca local: allIssues guarda a ultima resposta e o modelo e reconstruido a cada
    // mudanca de query, sem nova requisicao
    property var allIssues: []
    property string query: ""
    property int visibleCount: 0
    // repo -> quantidade (para o cabecalho) e se ha mais de um dono (para mostrar "dono/")
    property var repoCounts: ({})
    property bool showOwner: false
    readonly property string filterType: Plasmoid.configuration.filterType

    // Lista achatada e ordenada por repo; a UI usa ListView.section para os cabecalhos.
    ListModel {
        id: issuesModel
    }
    readonly property alias model: issuesModel

    readonly property var xhrHttp: HTTP.makeXhrHttp()

    // GH_TOKEN primeiro (CI/teste), senao o login atual do gh. Sem `set -x`, sem eco em log.
    readonly property string tokenCommand: 'printf %s "${GH_TOKEN:-$(gh auth token 2>/dev/null)}"'

    toolTipMainText: i18n("GitHub Issues")
    toolTipSubText: errorCode !== "" ? errorText(errorCode)
                  : i18np("%1 issue aberta", "%1 issues abertas", totalCount)

    compactRepresentation: CompactRepresentation {
        count: root.totalCount
        hasError: root.errorCode !== ""
        onActivated: root.expanded = !root.expanded
    }
    fullRepresentation: FullRepresentation {
        issues: root.model
        loading: root.loading
        errorMessage: root.errorCode !== "" ? root.errorText(root.errorCode) : ""
        totalCount: root.totalCount
        visibleCount: root.visibleCount
        repoCounts: root.repoCounts
        showOwner: root.showOwner
        query: root.query
        lastUpdate: root.lastUpdate
        onRefreshRequested: root.refresh()
        onSearchChanged: text => root.query = text
    }

    // Mensagens em portugues para cada codigo de erro tipado de github.mjs/http.mjs
    function errorText(code) {
        switch (code) {
        case "no_token":   return i18n("Sem token. Rode `gh auth login` no terminal.")
        case "auth":       return i18n("Token inválido ou expirado. Rode `gh auth login`.")
        case "rate_limit": return i18n("Limite de requisições do GitHub atingido. Tente mais tarde.")
        case "network":    return i18n("Sem conexão com o GitHub.")
        default:           return i18n("Erro ao consultar o GitHub.")
        }
    }

    // Ponto de entrada: busca o token e, no retorno, carrega as issues.
    function refresh() {
        if (loading) return;
        loading = true;
        errorCode = "";
        tokenSource.connectSource(tokenCommand);
    }

    function loadIssues(token) {
        GH.fetchAllIssues(xhrHttp, token, filterType, { includePRs: Plasmoid.configuration.includePRs })
            .then(list => {
                allIssues = list;
                totalCount = list.length;
                lastUpdate = new Date();
                loading = false;
                rebuildModel();
            })
            .catch(e => {
                errorCode = e && e.code ? e.code : "unknown";
                loading = false;
            });
    }

    // Reconstroi o modelo a partir de allIssues aplicando a busca. groupByRepo garante
    // ordem estavel: repos por atividade recente, issues mais recentes primeiro.
    function rebuildModel() {
        const shown = GH.filterIssues(allIssues, query);
        const counts = {};
        issuesModel.clear();
        for (const group of GH.groupByRepo(shown)) {
            counts[group.repo] = group.issues.length;
            for (const i of group.issues) {
                issuesModel.append({
                    repo: i.repo, title: i.title, number: i.number, url: i.url,
                    author: i.author, comments: i.comments, isPullRequest: i.isPullRequest,
                    age: GH.ageLabel(i.updatedAt),
                    // JSON porque array em ListModel vira sub-ListModel (sem .length)
                    labelsJson: JSON.stringify(i.labels)
                });
            }
        }
        repoCounts = counts;
        visibleCount = shown.length;
        // Calculado sobre a lista inteira (nao a filtrada) para o cabecalho nao
        // mudar de formato enquanto o usuario digita
        showOwner = new Set(allIssues.map(i => i.repo.split("/")[0])).size > 1;
    }
    onQueryChanged: rebuildModel()

    // "executable" roda o comando e devolve stdout em onNewData. Desconecta logo depois
    // para que o mesmo comando possa ser disparado de novo no proximo refresh.
    Plasma5Support.DataSource {
        id: tokenSource
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            root.loadIssues(String(data["stdout"] || "").trim());
        }
    }

    Timer {
        interval: Math.max(1, Plasmoid.configuration.refreshMinutes) * 60000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    // Trocar filtro ou "incluir PRs" recarrega na hora, sem esperar o timer
    Connections {
        target: Plasmoid.configuration
        function onFilterTypeChanged() { root.refresh(); }
        function onIncludePRsChanged() { root.refresh(); }
    }

    Component.onCompleted: refresh()
}
