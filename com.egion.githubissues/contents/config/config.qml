import QtQuick
import org.kde.plasma.configuration

// "source" resolve relativo a contents/ui/, nao a contents/config/
ConfigModel {
    ConfigCategory {
        name: i18n("Geral")
        icon: "configure"
        source: "configGeneral.qml"
    }
}
