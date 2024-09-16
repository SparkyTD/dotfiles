import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import GioUnix from 'gi://GioUnix'; // Import the Unix-specific library

export class RealTimeCommandRunner {
    private process: Gio.Subprocess | null = null;
    private stdoutStream: Gio.DataInputStream | null = null;
    private restartTimeout: number = 2000; // 2 seconds before restarting
    private command: string;
    private args: string[];

    constructor(command: string, args: string[], private onOutput: (data: string) => void) {
        this.command = command;
        this.args = args;
    }

    // Start the process
    start(): void {
        this._startProcess();
    }

    // Stop the process
    stop(): void {
        if (this.process) {
            this.process.force_exit();
            this.process = null;
        }
    }

    // Internal function to start the process and handle output
    private _startProcess(): void {
        try {
            // Create the subprocess
            this.process = new Gio.Subprocess({
                argv: [this.command, ...this.args],
                flags: Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE,
            });

            // Initiate the subprocess
            this.process.init(null);

            // Use GioUnix.InputStream to handle Unix-specific input stream (stdout pipe)
            const stdoutPipe = new GioUnix.InputStream({
                base_stream: this.process.get_stdout_pipe(),
                close_fd: true,
            });

            // Wrap it in a DataInputStream to read line-by-line
            this.stdoutStream = new Gio.DataInputStream({
                base_stream: stdoutPipe,
            });

            // Start reading the output in real-time
            this._readOutput();

            // Monitor the process exit status and restart if necessary
            GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 1, () => {
                if (!this.process || !this.process.get_if_exited()) {
                    return true; // Continue monitoring
                }
                // If the process has exited, restart it
                console.log('Process exited, restarting...');
                this._restartProcess();
                return false; // Stop monitoring this process
            });
        } catch (error) {
            console.error('Failed to start process:', error);
        }
    }

    // Read output from the process in real-time
    private _readOutput(): void {
        if (!this.stdoutStream) return;

        this.stdoutStream.read_line_async(0, null, (stream, result) => {
            if (!stream) return;

            try {
                const [line] = this.stdoutStream!.read_line_finish(result);
                if (line) {
                    // Process the output in real-time
                    this.onOutput(line);
                }
            } catch (error) {
                console.error('Error reading stdout:', error);
            }

            // Continue reading lines
            this._readOutput();
        });
    }

    // Restart the process after a delay if it dies
    private _restartProcess(): void {
        this.stop(); // Ensure the process is stopped

        // Restart the process after a timeout
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, this.restartTimeout, () => {
            console.log('Restarting process...');
            this._startProcess();
            return false; // Don't repeat this timeout
        });
    }
}

let runner = null;
let listeners = [];

export const registerJournalMonitor = (callback: (output: string) => any) => {
    return;
    if (!runner) {
        runner = new RealTimeCommandRunner('journalctl', ['-f'], (data: string) => {
            listeners.forEach(l => l(data));
        });
        runner.start();
    }

    if (!!callback)
        listeners.push(callback);
}

// Start the command runner
// runner.start();
