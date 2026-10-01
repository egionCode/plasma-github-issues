/*
 * IssueDelegate.qml: uma linha da lista (titulo, numero, labels, idade).
 * Clique abre a issue no navegador; clique direito abre o menu (abrir, copiar link,
 * marcar como vista). Roles vem do ListModel de main.qml (linhas kind == "issue").
 * labelTextColor (github.mjs) garante contraste do texto sobre a cor de cada label.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "../code/github.mjs" as GH

PlasmaComponents.ItemDelegate {
    id: delegate

    // Roles do modelo, declarados para evitar ReferenceError se faltar algum
    required property string title
    required property int number
    required property string url
    required property string age
    required property string labelsJson
    required property bool isPullRequest
    required property int comments
    required property bool isNew
    required property string key
    required property bool indented
    required property bool showRepo
    required property string repoLabel

    signal opened(string key)
    signal copyRequested(string text)
    signal seenRequested(string key)

    // Parse unico; array vazio quando a issue nao tem labels
    readonly property var labelList: JSON.parse(labelsJson)

    width: ListView.view ? ListView.view.width : implicitWidth
    // Recuo sob o cabecalho do repo (modo agrupado) para a hierarquia ficar legivel;
    // no modo plano nao ha cabecalho, entao o padding e o normal
    leftPadding: indented ? Kirigami.Units.gridUnit * 1.5 : Kirigami.Units.largeSpacing
    // Abrir conta como ver: limpa o destaque dessa issue
    function open() {
        Qt.openUrlExternally(url);
        opened(key);
    }
    onClicked: open()

    // Barra lateral de destaque para issues novas ou atualizadas desde a ultima vez
    Rectangle {
        visible: delegate.isNew
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom
                  topMargin: 3; bottomMargin: 3 }
        width: 3
        radius: 1
        color: Kirigami.Theme.highlightColor
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: menu.popup()
    }
    PlasmaComponents.Menu {
        id: menu
        PlasmaComponents.MenuItem {
            text: i18n("Abrir no navegador")
            icon.name: "internet-web-browser"
            onClicked: delegate.open()
        }
        PlasmaComponents.MenuItem {
            text: i18n("Copiar link")
            icon.name: "edit-copy"
            onClicked: delegate.copyRequested(delegate.url)
        }
        PlasmaComponents.MenuItem {
            visible: delegate.isNew
            text: i18n("Marcar como vista")
            icon.name: "checkmark"
            onClicked: delegate.seenRequested(delegate.key)
        }
    }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: delegate.isPullRequest ? "vcs-merge-request" : "media-record"
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: delegate.title
                font.bold: delegate.isNew
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
            }
            // Comentarios so aparecem se houver, para nao poluir linhas sem discussao
            Row {
                visible: delegate.comments > 0
                spacing: 2
                opacity: 0.6
                Kirigami.Icon {
                    source: "mail-message"
                    width: Kirigami.Units.iconSizes.small
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                }
                PlasmaComponents.Label { text: delegate.comments }
            }
            PlasmaComponents.Label {
                text: "#" + delegate.number
                opacity: 0.6
            }
            PlasmaComponents.Label {
                text: delegate.age
                opacity: 0.6
            }
        }

        // Repo (so no modo sem agrupamento, onde nao ha cabecalho) e labels. Some por
        // inteiro quando nao ha nenhum dos dois, para nao reservar altura a toa
        Flow {
            Layout.fillWidth: true
            visible: delegate.showRepo || delegate.labelList.length > 0
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                visible: delegate.showRepo
                text: delegate.repoLabel
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                font.bold: true
                opacity: 0.7
            }

            Repeater {
                model: delegate.labelList
                delegate: Rectangle {
                    required property var modelData
                    width: labelText.implicitWidth + Kirigami.Units.largeSpacing
                    height: labelText.implicitHeight + 2
                    radius: height / 2
                    color: "#" + modelData.color

                    PlasmaComponents.Label {
                        id: labelText
                        anchors.centerIn: parent
                        text: modelData.name
                        color: GH.labelTextColor(modelData.color)
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                }
            }
        }
    }
}
