/**
 * This file is part of the DVS Mode Switcher project.
 *
 * (c) 2024 Caleb <ko4uyj@gmail.com>
 *
 * For the full copyright and license information, see the
 * LICENSE file that was distributed with this source code.
 */

document.getElementById('talkgroup-form').addEventListener('submit', function(e) {
    e.preventDefault();

    // Retrieve values from the dropdown and manual input field
    const dropdownTgid = document.getElementById('talkgroup').value;
    const manualTgid = document.getElementById('manual-talkgroup')?.value.trim();

    // Determine which TGID to use: manual input takes priority
    const tgid = encodeURIComponent(manualTgid || dropdownTgid);

    if (!tgid) {
        showMessage('Please select or enter a valid talkgroup ID.');
        return;
    }

    // Send the TGID to the server
    fetch(`/tune/${tgid}`)
        .then(response => response.text())
        .then(() => {
            showMessage(`Switched to talkgroup ID: ${tgid}`);
        })
        .catch(error => {
            console.error('Error switching talkgroup:', error);
            showMessage('Failed to switch talkgroup.');
        });
});

function updateTalkgroups() {
    const mode = document.getElementById('mode').value;

    if (!mode) {
        showMessage('Please select a mode.');
        return;
    }

    fetch(`/mode/${mode}`)
        .then(response => response.json())
        .then(talkgroups => {
            const talkgroupSelect = document.getElementById('talkgroup');
            talkgroupSelect.innerHTML = ''; // Clear existing options

            talkgroups.forEach(tg => {
                const option = document.createElement('option');
                option.value = tg.tgid;
                option.textContent = `${tg.alias} (${tg.tgid})`;
                talkgroupSelect.appendChild(option);
            });

            showMessage(`Switched to mode: ${mode}`);
        })
        .catch(error => {
            console.error('Error updating talkgroups:', error);
            showMessage('Failed to update talkgroups.');
        });
}

const dmrNetworkLabels = {
    tgif: 'TGIF',
    bm: 'BrandMeister'
};

function setDmrNetworkDisplay(network) {
    const status = document.getElementById('dmr-network-status');
    const label = dmrNetworkLabels[network] || 'Unknown';
    status.textContent = 'Active DMR network: ' + label;
    status.className = network === 'tgif' ? 'alert alert-success py-2 text-center' : network === 'bm' ? 'alert alert-primary py-2 text-center' : 'alert alert-warning py-2 text-center';
    document.querySelectorAll('[data-dmr-network]').forEach(button => {
        const active = button.dataset.dmrNetwork === network;
        button.classList.toggle('active', active);
        button.setAttribute('aria-pressed', active ? 'true' : 'false');
    });
}

function setDmrButtonsDisabled(disabled) {
    document.querySelectorAll('[data-dmr-network]').forEach(button => {
        button.disabled = disabled;
    });
}

async function loadDmrNetworkStatus() {
    try {
        const response = await fetch('/dmr-network/status');
        if (response.ok === false) {
            throw new Error('Unable to read DMR network status');
        }
        const result = await response.json();
        setDmrNetworkDisplay(result.network);
    } catch (error) {
        console.error('Error reading DMR network status:', error);
        setDmrNetworkDisplay('unknown');
    }
}

async function switchDmrNetwork(network) {
    if (Object.prototype.hasOwnProperty.call(dmrNetworkLabels, network) === false) {
        showMessage('Invalid DMR network.');
        return;
    }

    const status = document.getElementById('dmr-network-status');
    setDmrButtonsDisabled(true);
    status.textContent = 'Switching to ' + dmrNetworkLabels[network] + '...';
    status.className = 'alert alert-warning py-2 text-center';

    try {
        const response = await fetch('/dmr-network/' + network, { method: 'POST' });
        const result = await response.json();
        if (response.ok === false) {
            throw new Error(result.error || 'Unable to switch DMR network');
        }

        setDmrNetworkDisplay(result.network);
        document.getElementById('mode').value = 'DMR';

        const favoritesResponse = await fetch('/talkgroups/DMR');
        if (favoritesResponse.ok === false) {
            throw new Error('Network changed, but DMR favorites could not be loaded');
        }
        const talkgroups = await favoritesResponse.json();
        const talkgroupSelect = document.getElementById('talkgroup');
        talkgroupSelect.innerHTML = '';
        talkgroups.forEach(tg => {
            const option = document.createElement('option');
            option.value = tg.tgid;
            option.textContent = tg.alias + ' (' + tg.tgid + ')';
            talkgroupSelect.appendChild(option);
        });

        showMessage('DMR network switched to ' + dmrNetworkLabels[result.network] + '.');
    } catch (error) {
        console.error('Error switching DMR network:', error);
        showMessage(error.message);
        await loadDmrNetworkStatus();
    } finally {
        setDmrButtonsDisabled(false);
    }
}

function showMessage(message) {
    const banner = document.getElementById('message-banner');
    banner.textContent = message;
    banner.style.display = 'block';
    setTimeout(() => {
        banner.style.display = 'none';
    }, 3000);
}

document.addEventListener('DOMContentLoaded', function() {
    loadDmrNetworkStatus();
});
