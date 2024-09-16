import Gio from "gi://Gio";

export const activeSession = Variable(null);

const getProcessOutput = (args: string[], callback: (error: Error | null, stdout?: string) => any) => {
    const process = new Gio.Subprocess({
        argv: ["/usr/bin/openvpn3", ...args],
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

export enum Status {
    Disconnected = "disconnected",
    Disconnecting = "disconnecting",
    Connected = "connected",
    Connecting = "connecting"
};

export type Session = {
    path: string,
    name: string,
    status: string
};

export const getActiveSession = (callback: (error: Error | null, found: boolean, session?: Session) => any) => {
    getProcessOutput(["sessions-list"], (error, output) => {
        const pathMatch = /Path: (.+?)\s*\n/.exec(output);
        const nameMatch = /Config name: (.+?)\s*\n/.exec(output);
        const statusMatch = /Status: (.+?)\s*\n/.exec(output);

        if (!!error) {
            callback(error);
        } else if (!pathMatch || !nameMatch || !statusMatch || pathMatch.length != 2 || nameMatch.length != 2 || statusMatch.length != 2) {
            callback(null, false, null);
        } else {
            const status = statusMatch[1].includes("Client connected")
                ? Status.Connected
                : Status.Disconnected;
            callback(null, true, {
                path: pathMatch[1],
                name: nameMatch[1],
                status: status
            });
        }
    });
};

export type Config = {
    path: string,
    name: string
};

export const getConfigs = (callback: (error: Error | null, configs: Config[]) => any) => {
    getProcessOutput(["configs-list", "--json"], (error, output) => {
        if (!!error) {
            callback(error);
        } else {
            const entries = JSON.parse(output);
            let configs = [];
            for (const entryPath in entries) {
                const entry = entries[entryPath];
                const config = {
                    "path": entryPath,
                    "name": entry.name
                };
                configs.push(config);
            }
            callback(null, configs);
        }
    });
};

export const disconnectSession = (callback: (error: Error | null) => any) => {
    if (!activeSession.value || activeSession.value.status !== Status.Connected)
        return;

    getProcessOutput(["session-manage", "-D", "-c", activeSession.value.name], (error, output) => {
        if (output.includes("Connection statistics")) {
            activeSession.value = undefined;
            if (!!callback)
                callback(null);
        } else if (!!error) {
            callback(error);
        } else {
            callback(new Error(output));
        }
    });
};

const setActive = (config: Config | null, status: Status): Session => {
    if (!config) {
        activeSession.value = null;
    } else {
        activeSession.value = {
            path: config.path,
            name: config.name,
            status: status
        };
    }

    return activeSession.value;
};

export const connectSession = (config: Config, callback: (error: Error | null, session: Session) => any, flag: boolean) => {

    if (!!activeSession.value && activeSession.value.path === config.path)
        return;

    if (!!activeSession.value && activeSession.value.status !== Status.Disconnected && !flag) {
        disconnectSession(error => {
            if (!!error)
                connectSession(config, callback, true);
            else {
                setActive(null);
                callback(error, null);
            }
        });
        return;
    }

    setActive(config, Status.Connecting);

    getProcessOutput(["session-start", "-c", config.name], (error, output) => {
        if (output.includes("Connected")) {
            setActive(config, Status.Connected);
            if (!!callback) {
                setActive(null);
                callback(null, activeSession.value);
            }
        } else if (!!error) {
            setActive(null);
            callback(error);
            setActive(null);
        } else {
            setActive(null);
            callback(new Error(output))
            setActive(null);
        }
    });
}
