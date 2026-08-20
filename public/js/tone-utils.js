/*
    * From whackerlink
 */

let toneAudioCtx = null;

let inited = false;

async function setup() {
    if (inited) {
        return;
    }

    inited = true;
    toneAudioCtx = await new (window.AudioContext || window.webkitAudioContext)();
    await sleep(500);
}

function sleep(ms) {
    return new Promise((resolve) => {
        setTimeout(resolve, ms);
    });
}

function beep(frequency, duration, volume, type) {
    if (!toneAudioCtx) {
        return;
    }

    var oscillator = toneAudioCtx.createOscillator();
    var gainNode = toneAudioCtx.createGain();

    oscillator.connect(gainNode);
    gainNode.connect(toneAudioCtx.destination);
    vol = 1;
    gainNode.gain.value = vol;
    oscillator.frequency.value = frequency;
    oscillator.type = type;

    oscillator.start();

    setTimeout(
        function () {
            oscillator.stop();
        },
        duration
    );
}

function tpt_generate(){
    if (!toneAudioCtx) {
        return;
    }

    beep(910, 30, 20, 'sine');
    setTimeout(function () {
        beep(0, 20, 20, 'sine');
    }, 30);
    setTimeout(function () {
        beep(910, 30, 20, 'sine');
    }, 50);
    setTimeout(function () {
        beep(0, 20, 20, 'sine');
    }, 80);
    setTimeout(function () {
        beep(910, 50, 20, 'sine');
    }, 100);
}

function play_page_alert(){
    if (!toneAudioCtx) {
        return;
    }

    beep(910, 150, 20, 'sine');
    setTimeout(function () {
        beep(0, 150, 20, 'sine');
    }, 150);
    setTimeout(()=>{
        beep(910, 150, 20, 'sine');
    }, 300);
    setTimeout(()=>{
        beep(0, 150, 20, 'sine');
    }, 450);
    setTimeout(()=>{
        beep(910, 150, 20, 'sine');
    }, 600);
    setTimeout(()=>{
        beep(0, 150, 20, 'sine');
    }, 750);
    setTimeout(()=>{
        beep(910, 150, 20, 'sine');
    }, 900);
}

function emergency_tone_generate(){
    if (!toneAudioCtx) {
        return;
    }

    beep(610, 500, 20, 'sine');
    setTimeout(function () {
        beep(910, 500, 20, 'sine');
    }, 500);
    setTimeout(function () {
        beep(610, 500, 20, 'sine');
    }, 1000);
    setTimeout(function () {
        beep(910, 500, 20, 'sine');
    }, 1500);
}

function bonk(){
    if (!toneAudioCtx) {
        return;
    }

    beep(310, 1000, 5, 'sine');
}