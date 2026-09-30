/*
 * FullRepresentation.qml: popup/desktop com filtro, botao de atualizar e a lista.
 * Estados: carregando, erro (com mensagem), vazio e lista agrupada por repo.
 * O filtro escolhido e gravado em Plasmoid.configuration.filterType (persiste).
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: full

    property var issues
    property bool loading: false
    property string errorMessage: ""
    property int totalCount: 0
    property var lastUpdate: null
    signal refreshRequested()

    Layout.minimumWidth: Kirigami.Units.gridUnit * 20
    Layout.minimumHeight: Kirigami.Units.gridUnit * 16
    Layout.preferredWidth: Kirigami.Units.gridUnit * 24
    Layout.preferredHeight: Kirigami.Units.gridUnit * 28
    spacing: Kirigami.Units.smallSpacing

    // value precisa bater com FILTERS de github.mjs
    readonly property var filterOptions: [
        { text: i18n("Atribuídas a mim"), value: "assigned" },
        { text: i18n("Criadas por mim"),  value: "created" },
        { text: i18n("Mencionadas"),      value: "mentioned" },
        { text: i18n("Nos meus repos"),   value: "repos" },
        { text: i18n("Todas"),            value: "all" }
    ]

    RowLayout {
        Layout.fillWidth: true
        Layout.margins: Kirigami.Units.smallSpacing

        PlasmaComponents.ComboBox {
            id: filterBox
            Layout.fillWidth: true
            model: full.filterOptions
            textRole: "text"
            valueRole: "value"
            // Sincroniza com a config salva; activated so dispara por acao do usuario,
            // entao nao cria laco com a mudanca vinda da config
            currentIndex: Math.max(0, indexOfValue(Plasmoid.configuration.filterType))
            onActivated: Plasmoid.configuration.filterType = currentValue
        }
        PlasmaComponents.ToolButton {
            icon.name: "view-refresh"
            enabled: !full.loading
            onClicked: full.refreshRequested()
            PlasmaComponents.ToolTip { text: i18n("Atualizar") }
        }
    }

    // Faixa de erro acima da lista: mantem as issues antigas visiveis quando ha cache
    PlasmaExtras.Heading {
        visible: full.errorMessage !== "" && listView.count > 0
        Layout.fillWidth: true
        Layout.margins: Kirigami.Units.smallSpacing
        level: 5
        color: Kirigami.Theme.negativeTextColor
        text: full.errorMessage
        wrapMode: Text.Wrap
    }

    StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        // 0 = lista, 1 = mensagem (erro/vazio/carregando)
        currentIndex: (listView.count > 0) ? 0 : 1

        PlasmaComponents.ScrollView {
            ListView {
                id: listView
                model: full.issues
                clip: true
                section.property: "repo"
                section.criteria: ViewSection.FullString
                section.delegate: PlasmaExtras.ListSectionHeader {
                    required property string section
                    width: ListView.view.width
                    label: section
                }
                delegate: IssueDelegate {}
            }
        }

        PlasmaExtras.PlaceholderMessage {
            // Prioridade: erro, carregando, vazio
            iconName: full.errorMessage !== "" ? "dialog-error"
                    : full.loading ? "view-refresh" : "checkmark"
            text: full.errorMessage !== "" ? full.errorMessage
                : full.loading ? i18n("Carregando...")
                : i18n("Nenhuma issue aberta neste filtro")
            width: parent.width - Kirigami.Units.gridUnit * 4
        }
    }

    PlasmaComponents.Label {
        visible: full.lastUpdate !== null
        Layout.fillWidth: true
        Layout.margins: Kirigami.Units.smallSpacing
        horizontalAlignment: Text.AlignRight
        opacity: 0.6
        font: Kirigami.Theme.smallFont
        text: full.lastUpdate
            ? i18np("%1 issue", "%1 issues", full.totalCount) + " · " +
              i18n("atualizado às %1", Qt.formatTime(full.lastUpdate, "hh:mm"))
            : ""
    }
}
