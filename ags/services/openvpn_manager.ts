import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import Service from '../service.js';

Gio._promisify(Gio.DataInputStream.prototype, 'read_upto_async');

export class OpenVPNDaemon extends Service {
    static {
        Service.register(this, {
            'event': ['string', 'string'],
            'config-list': ['string'],
            'config-import': ['string'],
            'config-delete': ['string'],
            'config-export': ['string'],
            'session-start': ['string'],
            'session-status': ['string'],
        });
    }

    private _decoder = new TextDecoder();
    private _encoder = new TextEncoder();

    constructor() {
        super();
        this._watchSocket(new Gio.DataInputStream({
            close_base_stream: true,
            base_stream: this._connection().get_input_stream(),
        }));
    }

    private _connection() {
        const socketPath = '/run/ovpnd-daemon.sock';
        return new Gio.SocketClient().connect(new Gio.UnixSocketAddress({ path: socketPath }), null);
    }

    private _watchSocket(stream: Gio.DataInputStream) {
        stream.read_line_async(0, null, (stream, result) => {
            if (!stream) return console.error('Error reading OpenVPN daemon socket');

            const [line] = stream.read_line_finish(result);
            const decodedLine = this._decoder.decode(line);

            // Handle status change events
            if (decodedLine.startsWith('!')) {
                this._handleStatusChangeEvent(decodedLine);
            } else {
                this._onResponse(decodedLine);
            }

            this._watchSocket(stream); // Continue watching the socket
        });
    }

    private _handleStatusChangeEvent(event: string) {
        const [uuid, name, status] = event.slice(1).split(':');
        this.emit('event', uuid, name, status);
    }

    private _onResponse(response: string) {
        const [length, status, message] = this._parseResponse(response);
        if (status === 'ok') {
            this.emit('event', 'response', message);
        } else {
            console.error('Error from OpenVPN daemon:', message);
        }
    }

    private _parseResponse(response: string): [number, string, string] {
        const [lengthStr, status, ...messageParts] = response.split(':');
        const message = messageParts.join(':');
        const length = parseInt(lengthStr, 10);
        return [length, status, message];
    }

    readonly sendCommand = (cmd: string): string => {
        const connection = this._connection();
        const stream = connection.get_output_stream();
        stream.write(this._encoder.encode(cmd), null);
        const inputStream = new Gio.DataInputStream({
            close_base_stream: true,
            base_stream: connection.get_input_stream(),
        });

        const [response] = inputStream.read_upto('\x04', -1, null);
        connection.close(null);
        return this._decoder.decode(response) || '';
    };

    readonly sendCommandAsync = async (cmd: string): Promise<string> => {
        const connection = this._connection();
        const stream = connection.get_output_stream();
        stream.write(this._encoder.encode(cmd), null);
        const inputStream = new Gio.DataInputStream({
            close_base_stream: true,
            base_stream: connection.get_input_stream(),
        });

        const result = await inputStream.read_upto_async('\x04', -1, 0, null);
        const [response] = result as unknown as [string, number];
        connection.close(null);
        return this._decoder.decode(response) || '';
    };

    // Specific commands
    readonly configList = () => this.sendCommandAsync('config list');
    readonly configImport = (name: string, path: string) =>
        this.sendCommandAsync(`config import -n ${name} -p ${path}`);
    readonly configDelete = (name: string) => this.sendCommandAsync(`config delete -n ${name}`);
    readonly configExport = (name: string) => this.sendCommandAsync(`config export -n ${name}`);
    readonly sessionStart = (name: string) => this.sendCommandAsync(`session start -n ${name}`);
    readonly sessionStatus = () => this.sendCommandAsync('session status');

    // Allow subscriptions to events
    onEvent(callback: (uuid: string, name: string, status: string) => void) {
        this.connect('event', (_, uuid, name, status) => callback(uuid, name, status));
    }
}

export const openVPNDaemon = new OpenVPNDaemon();
export default openVPNDaemon;

