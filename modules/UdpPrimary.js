const dgram = require('dgram');

class UdpPrimary {
    constructor(config, io) {
        this.io = io;
        this.config = config;

        if (this.config.usrp) {
            this.usrpEnabled = this.config.usrp.enabled || false;
            this.audioReceivePort = this.config.usrp.receivePort || 32005;
            this.audioSendPort = this.config.usrp.sendPort || 34010;
            this.audioReceiveAddress = this.config.usrp.receiveAddress || "0.0.0.0"
            this.audioSendAddress = this.config.usrp.sendAddress || "127.0.0.1"

            this.repeaterEnabled = this.config.usrp.repeater.enabled || false;
            this.repeaterSendPort = this.config.usrp.repeater.sendPort || 32001;
            this.repeaterSendAddress = this.config.usrp.repeater.sendIp || "127.0.0.1";
        } else {
            this.usrpEnabled = false;
            this.repeaterEnabled = false;
        }

        this.udpServer = dgram.createSocket('udp4');
        this.udpServer.on('message', (msg) => {
            this.io.emit('audio', msg);
            if (this.repeaterEnabled) {
                this.relayToRepeater(msg);
            }
        });

        this.io.on('connection', (socket) => {
            socket.on('audio', (msg) => {
                this.udpServer.send(msg, this.audioSendPort, this.audioSendAddress, (err) => {
                    if (err) {
                        console.error(`Error sending audio data: ${err}`);
                    }
                });
                if (this.repeaterEnabled) {
                    this.relayToRepeater(msg);
                }
            });
        });
    }

    bind() {
        this.udpServer.bind(this.audioReceivePort, this.audioReceiveAddress, () => {
            console.log(`Primary UDP Server listening on ${this.audioReceiveAddress}:${this.audioReceivePort}`);
        });
    }

    relayToRepeater(msg) {
        const repeaterUdpServer = dgram.createSocket('udp4');
        repeaterUdpServer.send(msg, this.repeaterSendPort, this.repeaterSendAddress, (err) => {
            if (err) {
                console.error(`Error relaying to repeater: ${err}`);
            }
        });
    }
}

module.exports = UdpPrimary;