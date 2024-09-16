import options from "options";
import Gdk from 'gi://Gdk?version=3.0';
import Gio from "gi://Gio";
import { openMenu } from "../utils.js";
// import { Session, Status, getActiveSession, getConfigs, activeSession } from "./helpers.ts";
import { Session, Status, Config, getClientInstance } from "./daemon-client.ts";

const OpenVPN3 = () => {
    /*getActiveSession((error, found, session) => {
        activeSession.value = session;
    });*/

    let client = getClientInstance();
    client.connect();
    client.updateActiveSession();

    const getSessionName = (session: Session) => {
        if (!session)
            return "Disconnected";

        return session.config.name;
    };

    const getSessionIcon = (session: Session) => {
        if (!session || session.status === Status.Stopped) {
            return "mintupdate-error";
        } else if (session.status === Status.Running) {
            return "mintupdate-up-to-date";
        } else {
            return "mintupdate-checking";
        }
    };

    // console.log(getClientInstance().getActiveSession());

    return {
        component: Widget.Box({
            class_name: "openvpn3",
            children: [
                Widget.Icon({
                    icon: client.activeSession.bind("value").as(s => getSessionIcon(s))
                }), 
                Widget.Label({
                    label: client.activeSession.bind("value").as(s => getSessionName(s))
                })
            ]
        }),
        isVisible: true,
        boxClass: "ovpn3",
        props: {
            on_primary_click: (clicked: any, event: Gdk.Event) => {
                openMenu(clicked, event, "openvpn3menu")
            }
        }
    };
};

export { OpenVPN3 };
