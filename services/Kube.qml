pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Current kubectl context, read straight out of ~/.kube/config rather than by
// shelling out to kubectl — the file is the source of truth and watching it
// costs nothing.
//
// Rules ported verbatim from the ags service (~/.config/ags/services/
// kubernetes.ts): strip the teleport prefix so `rs-prod` shows rather than
// `teleport.researchable.dev-rs-prod`, and treat master/prod/rs-devops as
// production.
Singleton {
    id: root

    property string context: ""
    readonly property bool production: context.includes("master")
        || context.includes("prod")
        || context === "rs-devops"

    FileView {
        id: kubeconfig
        path: `${Quickshell.env("HOME")}/.kube/config`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const m = text().match(/^current-context: (\S+)\s*$/m);
            if (!m) { root.context = ""; return; }
            // teleport.<host>.dev-<cluster> → <cluster>
            const tp = m[1].match(/^teleport\.\S+\.dev-(.+)$/);
            root.context = tp ? tp[1] : m[1];
        }
        onLoadFailed: root.context = ""
    }
}
