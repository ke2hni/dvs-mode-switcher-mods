class GRP_VCH_REQ {
    constructor(srcId, dstId) {
        this.srcId = srcId;
        this.dstId = dstId;
    }

    toString() {
        return `GRP_VCH_REQ srcId: ${this.srcId}, dstId: ${this.dstId}`;
    }
}

module.exports = GRP_VCH_REQ;