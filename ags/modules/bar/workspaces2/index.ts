const hyprland = await Service.import("hyprland");
import options from "options";
import { createThrottledScrollHandlers, getCurrentMonitorWorkspaces, getWorkspaceRules, getWorkspacesForMonitor } from "./helpers";
import { Workspace } from "types/service/hyprland";

const {
    workspaces,
    monitorSpecific,
    workspaceMask,
    scroll_speed,
    spacing
} = options.bar.workspaces;

function injectHyprEventInterceptor() {
    const originalEventHandler = hyprland["_onEvent"].bind(hyprland);
    if (hyprland["injectedVariable"] !== undefined) {
        return hyprland["injectedVariable"];
    }

    const currentWorkspace = Variable(Math.ceil(hyprland.active.workspace.id / hyprland.monitors.length));
    const newEventHandler = hyprland["_onEvent"] = async function(event: string) {
        const [e, params] = event.split('>>');
        const argv = params.split(',');

        if (e === "workspace") {
            const workspaceIndex = argv[0];
            if (workspaceIndex % hyprland.monitors.length === 0) {
                currentWorkspace.value = argv[0] / hyprland.monitors.length;
            }
        }

        await originalEventHandler(event);
    };
    hyprland["injectedVariable"] = currentWorkspace;

    return currentWorkspace;
}

String.prototype.replaceAt = function(index, replacement) {
    return this.substring(0, index) + replacement + this.substring(index + replacement.length);
}

function range(length: number, start = 1) {
    return Array.from({ length }, (_, i) => i + start);
}

const WorkspacesV2 = () => {

    const currentWorkspace = injectHyprEventInterceptor();
    const displayCount = options.bar.workspaces2.displayCount;

    return {
        component: Widget.Box({
            class_name: "workspaces2",
            children: Utils.merge(
                [displayCount.bind("value")],
                (displayCount: number) => {
                    return range(16)
                        .sort((a, b) => a - b)
                        .map((i, index) => {
                            return Widget.Button({
                                child: Widget.Label({
                                    vpack: "center",
                                    class_name: currentWorkspace
                                        .bind("value")
                                        .as(w => { 
                                            if(i == w)
                                                return "active";
                                            if(i > Math.max(w, displayCount))
                                                return "disabled";
                                            return "default";
                                        }),
                                }),
                                class_name: currentWorkspace
                                    .bind("value")
                                    .as(w => i > Math.max(w, displayCount) ? "disabled": "default")
                            });
                        })
                        .filter(e => e !== null);
                })
        }),
        isVisible: true,
        boxClass: "workspaces2"
    };
};

export { WorkspacesV2 };
