/**
 * This file is part of the DVSwitch Mode Switcher project.
 *
 * (c) 2024 Caleb <ko4uyj@gmail.com>
 *
 * For the full copyright and license information, see the
 * LICENSE file that was distributed with this source code.
 */

document.getElementById('talkgroup-form').addEventListener('submit', function(e) {
    e.preventDefault();
    const mode = document.getElementById('mode').value;
    const talkgroups = Array.from(document.querySelectorAll('#talkgroups-list tr')).map(row => ({
        alias: row.querySelector('input[name="alias"]').value,
        tgid: row.querySelector('input[name="tgid"]').value
    }));

    fetch('/save', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ mode, talkgroups })
    }).then(response => response.text()).then(data => alert(data));
});

function loadTalkgroups() {
    const mode = document.getElementById('mode').value;
    fetch(`/talkgroups/${mode}`)
        .then(response => response.json())
        .then(talkgroups => {
            document.getElementById('selected-mode').innerText = mode;
            const talkgroupsList = document.getElementById('talkgroups-list');
            talkgroupsList.innerHTML = '';
            talkgroups.forEach(tg => {
                const row = document.createElement('tr');
                row.innerHTML = `
                    <td><input type="text" class="form-control" name="alias" value="${tg.alias}"></td>
                    <td><input type="text" class="form-control" name="tgid" value="${tg.tgid}"></td>
                    <td><button type="button" class="btn btn-danger" onclick="deleteTalkgroup(this)">Delete</button></td>
                `;
                talkgroupsList.appendChild(row);
            });
        });
}

function addTalkgroup() {
    const row = document.createElement('tr');
    row.innerHTML = `
        <td><input type="text" class="form-control" name="alias"></td>
        <td><input type="text" class="form-control" name="tgid"></td>
        <td><button type="button" class="btn btn-danger" onclick="deleteTalkgroup(this)">Delete</button></td>
    `;
    document.getElementById('talkgroups-list').appendChild(row);
}

function deleteTalkgroup(button) {
    button.closest('tr').remove();
}

document.addEventListener('DOMContentLoaded', function() {
    loadTalkgroups();
});