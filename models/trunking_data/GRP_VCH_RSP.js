const { StatusCodes, getStatusCodeDisplay } = require('../StatusCodes');

class GRP_VCH_RSP {
    constructor(status, channel, srcId, dstId) {
        this.status = status;
        this.channel = channel;
        this.srcId = srcId;
        this.dstId = dstId;
    }

    toString() {
        return `GRP_VCH_RSP, status: ${getStatusCodeDisplay(this.status)}, channel: ${this.channel} srcId: ${this.srcId}, dstId: ${this.dstId}`;
    }
}

module.exports = GRP_VCH_RSP;