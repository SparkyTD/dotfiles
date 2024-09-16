const hyprland = await Service.import("hyprland");
import options from "options";
import Gio from "gi://Gio";
import { Workspace } from "types/service/hyprland";

const getProcessOutput = (path: string, args: string[], callback: (error: Error | null, stdout?: string) => any) => {
    const process = new Gio.Subprocess({
        argv: [path, ...args],
        flags: Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE
    });

    process.init(null);

    process.communicate_utf8_async(null, null, (proc, res) => {
        try {
            const [success, stdout, stderr] = proc.communicate_utf8_finish(res);

            if (success)
                callback(null, stdout);
            else
                callback(new Error(stderr));
        } catch (error) {
            callback(error);
        }
    });
};
const KeyboardLayout = () => {

    const layout = Variable("???");

    hyprland.connect("keyboard-layout", (instance, keyboard, lang) => {
        layout.value = lang;
    });

    getProcessOutput("/usr/bin/hyprctl", ["devices", "-j"], (error, output) => {
        const devices = JSON.parse(output);
        const mainKeyboards = devices.keyboards.filter(a => a.main === true);
        if (mainKeyboards.length > 0)
            layout.value = mainKeyboards[0].active_keymap;
    });

    return {
        component: Widget.Box({
            class_name: "keyboard_layout",
            child: Widget.Label({
                label: layout.bind("value").as(a => "\udb80\udf0c   " + a)
            })
        }),
        isVisible: true,
        boxClass: "keyboard_layout"
    };
};

export { KeyboardLayout };
