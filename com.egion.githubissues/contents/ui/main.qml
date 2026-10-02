/*
 * main.qml: raiz do plasmoid GitHub Issues.
 * Objetivo: manter o estado (issues, loading, erro, "novas"), buscar o token, chamar a
 *   API e alimentar as representacoes compacta e completa.
 * Dependencias: Plasma 6 (plasmoid, plasma5support, notification), code/github.mjs e
 *   code/http.mjs.
 * Decisoes:
 *   - O token vem de `gh auth token` (ou de GH_TOKEN, que tem prioridade e facilita
 *     testar erro de auth). Nunca e gravado em disco nem logado.
 *   - A logica de negocio fica em .mjs puros (testados em Node); aqui so cola de UI.
 *   - Duas comparacoes distintas: "novas" (destaque) compara com o que o usuario JA VIU
 *     (snapshot persistido); notificacao compara com a atualizacao ANTERIOR (memoria),
 *     para avisar uma vez so por issue.
 *   - Notificacao via org.kde.notification (sem shell), pois titulos de issue podem vir
 *     de terceiros e nao podem passar por interpretacao de shell.
 */
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.notification
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
    readonly property string filterType: Plasmoid.configuration.filterType
    readonly property bool grouped: Plasmoid.configuration.groupByRepo
    readonly property bool sortDesc: Plasmoid.configuration.sortDesc

    // Busca local: allIssues guarda a ultima resposta e o modelo e reconstruido a cada
    // mudanca de query/recolhimento, sem nova requisicao
    property var allIssues: []
    property string query: ""
    property int visibleCount: 0
    property bool showOwner: false

    // chave -> true das issues novas/atualizadas desde a ultima vez que o usuario viu
    property var newKeys: ({})
    property int newCount: 0
    // Snapshot da atualizacao anterior (so memoria); null ate a primeira carga da sessao
    property var previousLoad: null

    // Modelo plano: linhas "header" (repo) e "issue" intercaladas. Plano (e nao section)
    // porque recolher um repo precisa manter o cabecalho e remover so as issues.
    ListModel { id: issuesModel }
    readonly property alias model: issuesModel

    readonly property var xhrHttp: HTTP.makeXhrHttp()

    // GH_TOKEN primeiro (CI/teste), senao o login atual do gh. Sem `set -x`, sem eco em log.
    readonly property string tokenCommand: 'printf %s "${GH_TOKEN:-$(gh auth token 2>/dev/null)}"'

    toolTipMainText: i18n("GitHub Issues")
    toolTipSubText: errorCode !== "" ? errorText(errorCode)
                  : newCount > 0 ? i18np("%1 nova ou atualizada", "%1 novas ou atualizadas", newCount)
                  : i18np("%1 issue aberta", "%1 issues abertas", totalCount)

    compactRepresentation: CompactRepresentation {
        count: root.totalCount
        newCount: root.newCount
        hasError: root.errorCode !== ""
        onActivated: root.expanded = !root.expanded
    }
    fullRepresentation: FullRepresentation {
        issues: root.model
        loading: root.loading
        errorMessage: root.errorCode !== "" ? root.errorText(root.errorCode) : ""
        totalCount: root.totalCount
        visibleCount: root.visibleCount
        newCount: root.newCount
        showOwner: root.showOwner
        grouped: root.grouped
        sortDesc: root.sortDesc
        query: root.query
        lastUpdate: root.lastUpdate
        onRefreshRequested: root.refresh()
        onSearchChanged: text => root.query = text
        onRepoToggled: repo => root.toggleRepo(repo)
        onSortDirectionToggled: Plasmoid.configuration.sortDesc = !Plasmoid.configuration.sortDesc
        onGroupingToggled: Plasmoid.configuration.groupByRepo = !Plasmoid.configuration.groupByRepo
        onIssueOpened: key => root.markSeen(key)
        onMarkAllSeenRequested: root.markAllSeen()
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
                notifyIfNew(list);
                previousLoad = GH.snapshot(list);
                allIssues = list;
                totalCount = list.length;
                lastUpdate = new Date();
                loading = false;
                computeNew();
            })
            .catch(e => {
                errorCode = e && e.code ? e.code : "unknown";
                loading = false;
            });
    }

    // Avisa so de issues que NAO estavam na atualizacao anterior. Na primeira carga da
    // sessao previousLoad e null e diffIssues devolve vazio (sem aviso de "41 novas").
    function notifyIfNew(list) {
        if (!Plasmoid.configuration.notify) return;
        const added = GH.diffIssues(previousLoad, list).added;
        if (added.length === 0) return;
        const text = GH.notificationText(added);
        newIssuesNotification.title = text.title;
        newIssuesNotification.text = text.body;
        newIssuesNotification.sendEvent();
    }

    // "Novas" = adicionadas ou atualizadas desde o snapshot que o usuario ja viu.
    // Sem snapshot (primeira execucao) inicializa com o estado atual: nada pisca.
    function computeNew() {
        const seen = GH.parseSnapshot(Plasmoid.configuration.seenJson);
        if (seen === null) {
            markAllSeen();
            return;
        }
        const d = GH.diffIssues(seen, allIssues);
        const keys = {};
        for (const i of d.added.concat(d.updated)) keys[GH.issueKey(i)] = true;
        newKeys = keys;
        newCount = Object.keys(keys).length;
        rebuildModel();
    }

    function markAllSeen() {
        Plasmoid.configuration.seenJson = JSON.stringify(GH.snapshot(allIssues));
        newKeys = {};
        newCount = 0;
        rebuildModel();
    }

    // Marca uma issue como vista: atualiza so a chave dela no snapshot persistido
    function markSeen(key) {
        if (!newKeys[key]) return;
        const seen = GH.parseSnapshot(Plasmoid.configuration.seenJson) || {};
        const issue = allIssues.find(i => GH.issueKey(i) === key);
        if (issue) seen[key] = issue.updatedAt;
        Plasmoid.configuration.seenJson = JSON.stringify(seen);
        const keys = Object.assign({}, newKeys);
        delete keys[key];
        newKeys = keys;
        newCount = Object.keys(keys).length;
        rebuildModel();
    }

    function toggleRepo(repo) {
        const list = Plasmoid.configuration.collapsedRepos.slice();
        const i = list.indexOf(repo);
        if (i >= 0) list.splice(i, 1); else list.push(repo);
        Plasmoid.configuration.collapsedRepos = list;
    }

    // Reconstroi o modelo a partir de allIssues aplicando a busca e o modo de exibicao.
    // Agrupado: repos por atividade recente (groupByRepo), cabecalho + issues, com
    // recolhimento. Plano: so issues, ordenadas globalmente por atividade. Durante uma
    // busca o recolhimento e ignorado: esconder resultados que o usuario acabou de
    // procurar seria confuso.
    function rebuildModel() {
        const shown = GH.filterIssues(allIssues, query);
        const collapsed = Plasmoid.configuration.collapsedRepos;
        // Calculado sobre a lista inteira (nao a filtrada) para o rotulo do repo nao
        // mudar de formato enquanto o usuario digita
        showOwner = new Set(allIssues.map(i => i.repo.split("/")[0])).size > 1;
        issuesModel.clear();
        if (grouped) {
            for (const group of GH.groupByRepo(shown, Plasmoid.configuration.sortBy, Plasmoid.configuration.sortDesc)) {
                const isCollapsed = query === "" && collapsed.indexOf(group.repo) >= 0;
                issuesModel.append(row("header", group.repo, group.issues.length, isCollapsed, null));
                if (isCollapsed) continue;
                for (const i of group.issues) issuesModel.append(row("issue", group.repo, 0, false, i));
            }
        } else {
            for (const i of GH.sortIssues(shown, Plasmoid.configuration.sortBy, Plasmoid.configuration.sortDesc)) issuesModel.append(row("issue", i.repo, 0, false, i));
        }
        visibleCount = shown.length;
    }

    // Linha uniforme: header e issue compartilham os mesmos campos (ListModel exige
    // roles consistentes), os que nao se aplicam ficam com valor neutro.
    function row(kind, repo, count, collapsed, i) {
        return {
            kind: kind, repo: repo, count: count, collapsed: collapsed,
            key: i ? GH.issueKey(i) : "", isNew: i ? !!newKeys[GH.issueKey(i)] : false,
            title: i ? i.title : "", number: i ? i.number : 0, url: i ? i.url : "",
            author: i ? i.author : "", comments: i ? i.comments : 0,
            isPullRequest: i ? i.isPullRequest : false,
            age: i ? GH.ageLabel(i.updatedAt) : "",
            // JSON porque array em ListModel vira sub-ListModel (sem .length)
            labelsJson: JSON.stringify(i ? i.labels : []),
            // Apresentacao: recuo so sob cabecalho; repo na linha so sem cabecalho
            indented: grouped,
            showRepo: !grouped,
            repoLabel: showOwner ? repo : repo.substring(repo.indexOf("/") + 1)
        };
    }
    onQueryChanged: rebuildModel()

    // Fechar o popup conta como "vi": limpa os destaques. No desktop (sempre visivel)
    // expanded nao muda; la o usuario limpa clicando na issue ou em "marcar como vistas".
    // root.expanded explicito: o parametro injetado "expanded" esta depreciado no Qt 6
    onExpandedChanged: {
        if (!root.expanded && root.newCount > 0) root.markAllSeen();
    }

    Notification {
        id: newIssuesNotification
        // Evento generico do Plasma: evita exigir um .notifyrc proprio instalado no sistema
        componentName: "plasma_workspace"
        eventId: "notification"
        iconName: "vcs-normal"
    }

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

    // Trocar filtro ou "incluir PRs" recarrega na hora; recolher repo so reconstroi o modelo
    Connections {
        target: Plasmoid.configuration
        function onFilterTypeChanged() { root.refresh(); }
        function onIncludePRsChanged() { root.refresh(); }
        function onCollapsedReposChanged() { root.rebuildModel(); }
        function onGroupByRepoChanged() { root.rebuildModel(); }
        function onSortByChanged() { root.rebuildModel(); }
        function onSortDescChanged() { root.rebuildModel(); }
    }

    Component.onCompleted: refresh()
}
