/*
 * CompactRepresentation.qml: icone no painel com contador de issues.
 * Sinal activated: clique do usuario (main.qml alterna o popup).
 */
import QtQuick
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

MouseArea {
    id: compact

    property int count: 0
    property bool hasError: false
    signal activated()

    hoverEnabled: true
    onClicked: activated()

    Kirigami.Icon {
        anchors.fill: parent
        source: compact.hasError ? "dialog-warning" : "vcs-normal"
        active: compact.containsMouse
    }

    // Selo com o numero; escondido quando zero ou em erro para nao poluir o painel
    Rectangle {
        visible: compact.count > 0 && !compact.hasError
        anchors { right: parent.right; bottom: parent.bottom }
        width: Math.max(height, badgeText.implicitWidth + Kirigami.Units.smallSpacing * 2)
        height: Math.round(parent.height * 0.5)
        radius: height / 2
        color: Kirigami.Theme.highlightColor

        PlasmaComponents.Label {
            id: badgeText
            anchors.centerIn: parent
            text: compact.count > 99 ? "99+" : compact.count
            color: Kirigami.Theme.highlightedTextColor
            font.pixelSize: Math.max(8, parent.height * 0.65)
        }
    }
}
