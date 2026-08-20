const dgram = require('dgram');

class UdpRepeater {
    constructor(config) {
        this.config = config;

        if (this.config.usrp) {
            this.usrpEnabled = this.config.usrp.enabled || false;
            this.audioSendPort = this.config.usrp.sendPort || 34010;
            this.audioSendAddress = this.config.usrp.sendAddress || "127.0.0.1"

            this.repeaterReceivePort = this.config.usrp.repeater.receivePort || 34001;
            this.repeaterReceiveAddress = this.config.usrp.repeater.receiveIp || "0.0.0.0";
        } else {
            this.usrpEnabled = false;
        }

        this.repeaterUdpServer = dgram.createSocket('udp4');
        this.repeaterUdpServer.on('message', (msg) => {
            this.relayToPrimary(msg);
        });
    }

    bind() {
        this.repeaterUdpServer.bind(this.repeaterReceivePort, this.repeaterReceiveAddress, () => {
            console.log(`Repeater UDP Server listening on ${this.repeaterReceiveAddress}:${this.repeaterReceivePort}`);
        });
    }

    relayToPrimary(msg) {
        const udpServer = dgram.createSocket('udp4');
        udpServer.send(msg, this.audioSendPort, this.audioSendAddress, (err) => {
            if (err) {
                console.error(`Error relaying to primary: ${err}`);
            }
        });
    }
}

module.exports = UdpRepeater;