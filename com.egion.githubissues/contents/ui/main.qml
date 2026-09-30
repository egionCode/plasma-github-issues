/*
 * main.qml: raiz do plasmoid GitHub Issues.
 * Objetivo: hospedar as representacoes compacta e completa.
 * Dependencias: Plasma 6 (org.kde.plasma.plasmoid), Kirigami.
 * Por enquanto e apenas um placeholder para validar a instalacao do pacote.
 */
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents

PlasmoidItem {
    id: root

    // Placeholder ate a lista real (proximos commits)
    fullRepresentation: PlasmaComponents.Label {
        text: "GitHub Issues: em construcao"
    }
}
