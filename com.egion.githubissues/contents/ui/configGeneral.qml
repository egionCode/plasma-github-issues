/*
 * configGeneral.qml: pagina de configuracao (intervalo de atualizacao, incluir PRs, notificacoes).
 * Convencao do Plasma: propriedades cfg_<chave> sao copiadas de/para main.xml.
 * Erro de digitacao no sufixo falha em silencio (o valor nunca persiste).
 */
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_refreshMinutes: refreshSpin.value
    property alias cfg_includePRs: prCheck.checked
    property alias cfg_notify: notifyCheck.checked
    property alias cfg_groupByRepo: groupCheck.checked
    // Valores gravados na config, na mesma ordem das opcoes do combo
    readonly property var sortKeys: ["updated", "created", "comments", "title", "number"]
    property string cfg_sortBy: "updated"

    Kirigami.FormLayout {
        QQC2.SpinBox {
            id: refreshSpin
            Kirigami.FormData.label: i18n("Atualizar a cada (min):")
            from: 1
            to: 120
        }
        QQC2.CheckBox {
            id: groupCheck
            Kirigami.FormData.label: i18n("Lista:")
            text: i18n("Agrupar por repositório")
        }
        QQC2.ComboBox {
            id: sortCombo
            Kirigami.FormData.label: i18n("Ordenar por:")
            model: [i18n("Última atualização"), i18n("Data de criação"),
                    i18n("Mais comentadas"), i18n("Título"), i18n("Número")]
            currentIndex: Math.max(0, sortKeys.indexOf(cfg_sortBy))
            onActivated: cfg_sortBy = sortKeys[currentIndex]
        }
        QQC2.CheckBox {
            id: prCheck
            Kirigami.FormData.label: i18n("Pull requests:")
            text: i18n("Incluir na lista")
        }
        QQC2.CheckBox {
            id: notifyCheck
            Kirigami.FormData.label: i18n("Notificações:")
            text: i18n("Avisar quando chegar issue nova")
        }
    }
}
