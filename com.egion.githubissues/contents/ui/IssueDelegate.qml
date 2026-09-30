/*
 * IssueDelegate.qml: uma linha da lista (titulo, numero, labels, idade).
 * Clique abre a issue no navegador. Roles vem do ListModel de main.qml.
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

    // Parse unico; array vazio quando a issue nao tem labels
    readonly property var labelList: JSON.parse(labelsJson)

    width: ListView.view ? ListView.view.width : implicitWidth
    onClicked: Qt.openUrlExternally(url)

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

        // Labels so aparecem se existirem, para nao reservar altura a toa
        Flow {
            Layout.fillWidth: true
            visible: delegate.labelList.length > 0
            spacing: Kirigami.Units.smallSpacing

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
