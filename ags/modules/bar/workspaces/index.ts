const hyprland = await Service.import("hyprland");
import options from "options";
import { Workspace } from "types/service/hyprland";

const {
    workspaces,
    monitorSpecific,
    workspaceMask,
    scroll_speed,
    spacing
} = options.bar.workspaces;

function range(length: number, start = 1) {
    return Array.from({ length }, (_, i) => i + start);
}

const Workspaces = (monitor = -1) => {

    const defaultWses = () => {
        return Widget.Box({
            children: Utils.merge(
                [workspaces.bind("value")],
                (workspaces: number) => {
                    return range(workspaces || 8)
                        .sort((a, b) => a - b)
                        .map((i, index) => {
                            return Widget.Button({
                                class_name: "workspace-button",
                                child: Widget.Label({
                                    attribute: i,
                                    vpack: "center",
                                    css: spacing.bind("value").as(sp => `margin: 0rem ${0.375 * sp}rem;`),
                                    class_name: "default",
                                    setup: (self) => {
                                        self.hook(hyprland, () => {
                                            self.toggleClassName(
                                                "active",
                                                hyprland.active.workspace.id === i,
                                            );
                                            self.toggleClassName(
                                                "occupied",
                                                (hyprland.getWorkspace(i)?.windows || 0) > 0,
                                            );
                                        });
                                    },
                                })
                            });
                        });
                },
            )
        })
    }

    return {
        component: Widget.Box({
            class_name: "workspaces",
            child: defaultWses(),
        }),
        isVisible: true,
        boxClass: "workspaces"
    };
};

export { Workspaces };
