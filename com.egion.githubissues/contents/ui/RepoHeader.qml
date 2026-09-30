/*
 * RepoHeader.qml: cabecalho clicavel de um repo (recolhe/expande) com a contagem.
 * Roles vem do ListModel de main.qml (linhas kind == "header").
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

MouseArea {
    id: header

    required property string repo
    required property int count
    required property bool collapsed
    // Definido por FullRepresentation: sem "dono/" quando todos os repos tem o mesmo dono
    property bool showOwner: false
    signal toggled(string repo)

    width: ListView.view ? ListView.view.width : implicitWidth
    implicitHeight: row.implicitHeight + Kirigami.Units.largeSpacing
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: toggled(repo)

    // Destaque leve no hover para indicar que a linha e clicavel
    Rectangle {
        anchors.fill: parent
        color: Kirigami.Theme.highlightColor
        opacity: header.containsMouse ? 0.12 : 0
    }

    RowLayout {
        id: row
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                  leftMargin: Kirigami.Units.smallSpacing; rightMargin: Kirigami.Units.smallSpacing }
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: header.collapsed ? "arrow-right" : "arrow-down"
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: Kirigami.Units.iconSizes.small
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: header.showOwner ? header.repo : header.repo.substring(header.repo.indexOf("/") + 1)
            font.bold: true
            elide: Text.ElideRight
        }
        PlasmaComponents.Label {
            text: header.count
            opacity: 0.6
        }
    }
}
