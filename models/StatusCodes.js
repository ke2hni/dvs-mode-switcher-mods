const StatusCodes = Object.freeze({
    GRANT: 0,
    DENY: 1,
    REFUSE: 2,
    ERROR: 3
});

const StatusCodeNames = Object.freeze({
    0: 'GRANT',
    1: 'DENY',
    2: 'REFUSE',
    3: 'ERROR'
});

function getStatusCodeDisplay(value) {
    return StatusCodeNames[value] || 'UNKNOWN';
}

module.exports = {
    StatusCodes,
    getStatusCodeDisplay
};