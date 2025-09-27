document.addEventListener('DOMContentLoaded', function () {
    // Containers
    const menuContainer = document.getElementById('menu-container');
    const hudContainer = document.getElementById('hud-container');
    const resultsContainer = document.getElementById('results-container');

    // HUD elements
    const scoreElement = document.getElementById('score');
    const timerElement = document.getElementById('timer');

    // Results elements
    const finalScoreElement = document.getElementById('final-score');

    // Buttons
    const startGridshotButton = document.getElementById('start-gridshot');
    const closeResultsButton = document.getElementById('close-results');

    // NUI Message Listener
    window.addEventListener('message', function (event) {
        const data = event.data;
        const action = data.action;

        // Hide all containers by default on new message
        menuContainer.style.display = 'none';
        hudContainer.style.display = 'none';
        resultsContainer.style.display = 'none';

        if (action === 'showMenu') {
            menuContainer.style.display = 'block';
        } else if (action === 'showHud') {
            hudContainer.style.display = 'flex';
        } else if (action === 'showResults') {
            finalScoreElement.textContent = data.score;
            resultsContainer.style.display = 'block';
        } else if (action === 'updateHud') {
            hudContainer.style.display = 'flex'; // Ensure it's visible
            if (data.score !== undefined) {
                scoreElement.textContent = data.score;
            }
            if (data.time !== undefined) {
                timerElement.textContent = data.time;
            }
        } else if (action === 'updateHighscores') {
            const highscores = data.highscores;
            if (highscores) {
                populateHighscoreList('gridshot', highscores.gridshot);
                populateHighscoreList('tracking', highscores.tracking);
            }
        }
    });

    function populateHighscoreList(mode, scores) {
        const container = document.querySelector(`#highscore-${mode} .highscore-list`);
        if (!container) return;

        container.innerHTML = ''; // Clear previous scores

        if (scores && scores.length > 0) {
            scores.forEach(entry => {
                const scoreDiv = document.createElement('div');
                scoreDiv.className = 'highscore-entry';
                scoreDiv.innerHTML = `
                    <span class="highscore-name">${escapeHtml(entry.name)}</span>
                    <span class="highscore-score">${entry.score}</span>
                `;
                container.appendChild(scoreDiv);
            });
        } else {
            container.innerHTML = '<p>No scores yet.</p>';
        }
    }

    function escapeHtml(unsafe) {
        return unsafe
             .replace(/&/g, "&amp;")
             .replace(/</g, "&lt;")
             .replace(/>/g, "&gt;")
             .replace(/"/g, "&quot;")
             .replace(/'/g, "&#039;");
     }

    // --- Event Listeners for Buttons ---

    const targetSizeSlider = document.getElementById('target-size');
    const targetSizeValue = document.getElementById('target-size-value');

    targetSizeSlider.addEventListener('input', () => {
        targetSizeValue.textContent = `${targetSizeSlider.value}x`;
    });

    document.querySelectorAll('.start-game-btn').forEach(button => {
        button.addEventListener('click', () => {
            const mode = button.getAttribute('data-mode');
            const settings = {
                targetSize: parseFloat(targetSizeSlider.value)
            };

            fetch(`https://${GetParentResourceName()}/startGame`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({ mode: mode, settings: settings })
            }).then(resp => resp.json());
            menuContainer.style.display = 'none'; // Hide menu immediately
        });
    });

    closeResultsButton.addEventListener('click', () => {
        // Send message to Lua to close results and return to menu
        fetch(`https://${GetParentResourceName()}/closeResults`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({})
        }).then(resp => resp.json());
        resultsContainer.style.display = 'none'; // Hide results immediately
    });

    // Helper to close UI with Escape key
    document.onkeyup = function (data) {
        if (data.key === 'Escape') {
            fetch(`https://${GetParentResourceName()}/closeMenu`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({})
            }).then(resp => resp.json());
        }
    };
});