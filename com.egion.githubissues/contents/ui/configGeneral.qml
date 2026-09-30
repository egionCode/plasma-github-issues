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

    Kirigami.FormLayout {
        QQC2.SpinBox {
            id: refreshSpin
            Kirigami.FormData.label: i18n("Atualizar a cada (min):")
            from: 1
            to: 120
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
