import GLib from 'gi://GLib';
import Gio from 'gi://Gio';

Gio._promisify(Gio.DataInputStream.prototype, 'read_upto_async');

const SOCKET_PATH = "/run/ovpnd-daemon.sock";

export enum Status {
    Stopped = "Stopped",
    Stopping = "Stopping",
    Running = "Running",
    Starting = "Starting"
};

export type Session = {
    config: Config,
    status: string,
    started: string
};

export type Config = {
    guid: string,
    name: string
};

class OpenVPNDaemonClient {
    private _decoder = new TextDecoder();
    private _encoder = new TextEncoder();

    connected: boolean = false;
    activeSession: Variable<Session> = Variable(null);

    public connect() {
        if (this.connected === true)
            return;
        this.connected = true;

        this._watchSocket(new Gio.DataInputStream({
            close_base_stream: true,
            base_stream: this._connection().get_input_stream(),
        }));
    }

    private _connection() {
        return new Gio.SocketClient().connect(new Gio.UnixSocketAddress({ path: SOCKET_PATH }), null);
    }

    private _watchSocket(stream: Gio.DataInputStream) {
        stream.read_line_async(0, null, (stream, result) => {
            if (!stream)
                return console.error("Failed to read from OpenVPN daemon socket");

            const [line] = stream.read_line_finish(result);
            const decodedLine = this._decoder.decode(line);
            if (decodedLine.startsWith('!')) {
                this._onEvent(decodedLine.replace(/^!/g, ''));
            }

            this._watchSocket(stream);
        });
    }

    private _parseSocketMessage(message: string) {
        message = message.replace(/^\!/g, '');
        const length = parseInt(message.split(':', 1));
    }

    private _onEvent(event: string) {
        let [guid, name, status] = event.split(':').slice(1);

        this.activeSession.value = this.getActiveSession();
    }

    private _sendCommand(cmd: string): [boolean, string] {
        const connection = this._connection();
        const stream = connection.get_output_stream();
        stream.write(this._encoder.encode(cmd + "\n"), null);
        const inputStream = new Gio.DataInputStream({
            close_base_stream: true,
            base_stream: connection.get_input_stream()
        });

        let response = "";
        while (true) {
            const [line] = inputStream.read_line_utf8(null);
            if (line.startsWith('!'))
                continue;

            response = line;
            break;
        }

        let length = parseInt(response.split(':')[0]);
        response = response.split(':').splice(1).join(':');
        let bytesLeft = length - response.length - 1;

        while (bytesLeft > 0) {
            const [line] = inputStream.read_line_utf8(null);
            if (line.startsWith('!'))
                continue;

            response += line + '\n';
            bytesLeft -= line.length + 1;
        }

        connection.close(null);

        const arr = response.split(':');
        const success = arr[0] == "ok";
        const message = arr.splice(1).join(':');

        return [success, message];
    }

    public getConfigs(): Config[] {
        try {
            let [success, message] = this._sendCommand("config list");
            if (!success) {
                console.error(message);
                return [];
            }

            return JSON.parse(message) as Config[];
        } catch (e) {
            console.error(e);
            return [];
        }
    }

    public getConfigsCallback(callback: (error: Error | null, configs?: Config[]) => void) {
        try {
            let [success, message] = this._sendCommand("config list");
            if (!success) {
                return callback(new Error(message));
            }

            return callback(null, JSON.parse(message) as Config[]);
        } catch (e) {
            return callback(new Error(e as string));
        }
    }

    public getActiveSession(): Session | null {
        try {
            let [success, message] = this._sendCommand("session status");
            if (!success) {
                console.error(message);
                return null;
            }

            if (message === "No active sessions")
                return null;

            return JSON.parse(message) as Session;
        } catch (e) {
            console.error(e);
            return null;
        }
    }

    public getActiveSessionCallback(callback: (error: Error | null, session?: Session | null) => void) {
        try {
            let [success, message] = this._sendCommand("session status");
            if (!success) {
                return callback(new Error(message));
            }

            if (message === "No active sessions") {
                return callback(null, null);
            }

            return callback(null, JSON.parse(message) as Session);
        } catch (e) {
            return callback(new Error(e as string));
        }
    }

    public startSession(config: Config): Error | null {
        try {
            let [success, message] = this._sendCommand(`session start -n ${config.name}`);
            if (!success) {
                console.error(message);
                return new Error(message);
            }

            return null;
        } catch (e) {
            console.error(e);
            return new Error(e as string);
        }
    }

    public startSessionCallback(config: Config, callback: (error: Error | null) => void) {
        try {
            let [success, message] = this._sendCommand(`session start -n ${config.name}`);
            if (!success) {
                return callback(new Error(message));
            }

            return callback(null);
        } catch (e) {
            return callback(new Error(e as string));
        }
    }

    public stopSession(): Error | null {
        try {
            let [success, message] = this._sendCommand("session stop");
            if (!success) {
                console.error(message);
                return new Error(message);
            }

            return null;
        } catch (e) {
            console.error(e);
            return new Error(e as string);
        }
    }

    public stopSessionCallback(callback: (error: Error | null) => void) {
        try {
            let [success, message] = this._sendCommand("session stop");
            if (!success) {
                return callback(new Error(message));
            }

            return callback(null);
        } catch (e) {
            return callback(new Error(e as string));
        }
    }

    public updateActiveSession() {
        const activeSession = this.activeSession;
        this.getActiveSessionCallback((error, session) => {
            activeSession.value = session;
        });
    }
}

let instance;

export const getClientInstance = () => {
    if (!instance)
        instance = new OpenVPNDaemonClient();

    return instance;
};

