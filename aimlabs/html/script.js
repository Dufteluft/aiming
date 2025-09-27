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

    // Settings
    const targetSizeSlider = document.getElementById('target-size');
    const targetSizeValue = document.getElementById('target-size-value');

    // NUI Message Listener - The single source of truth for UI state
    window.addEventListener('message', function (event) {
        const data = event.data;
        if (!data.action) return;

        switch (data.action) {
            case 'showMenu':
                resultsContainer.style.display = 'none';
                hudContainer.style.display = 'none';
                menuContainer.style.display = 'block';
                break;
            case 'showHud':
                menuContainer.style.display = 'none';
                resultsContainer.style.display = 'none';
                hudContainer.style.display = 'flex';
                break;
            case 'showResults':
                menuContainer.style.display = 'none';
                hudContainer.style.display = 'none';
                finalScoreElement.textContent = data.score;
                resultsContainer.style.display = 'block';
                break;
            case 'hideAll':
                menuContainer.style.display = 'none';
                hudContainer.style.display = 'none';
                resultsContainer.style.display = 'none';
                break;
            case 'updateHud':
                if (data.score !== undefined) scoreElement.textContent = data.score;
                if (data.time !== undefined) timerElement.textContent = data.time;
                break;
            case 'updateHighscores':
                if (data.highscores) {
                    populateHighscoreList('gridshot', data.highscores.gridshot);
                    populateHighscoreList('tracking', data.highscores.tracking);
                }
                break;
        }
    });

    function populateHighscoreList(mode, scores) {
        const container = document.querySelector(`#highscore-${mode} .highscore-list`);
        if (!container) return;
        container.innerHTML = '';
        if (scores && scores.length > 0) {
            scores.forEach(entry => {
                const scoreDiv = document.createElement('div');
                scoreDiv.className = 'highscore-entry';
                scoreDiv.innerHTML = `<span class="highscore-name">${escapeHtml(entry.name)}</span><span class="highscore-score">${entry.score}</span>`;
                container.appendChild(scoreDiv);
            });
        } else {
            container.innerHTML = '<p>No scores yet.</p>';
        }
    }

    function escapeHtml(unsafe) {
        return unsafe.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#039;");
    }

    // --- Event Listeners for Buttons ---
    targetSizeSlider.addEventListener('input', () => {
        targetSizeValue.textContent = `${targetSizeSlider.value}x`;
    });

    document.querySelectorAll('.start-game-btn').forEach(button => {
        button.addEventListener('click', () => {
            const mode = button.getAttribute('data-mode');
            const settings = { targetSize: parseFloat(targetSizeSlider.value) };
            // ONLY send message, don't change UI state here
            fetch(`https://${GetParentResourceName()}/startGame`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({ mode: mode, settings: settings })
            });
        });
    });

    document.getElementById('close-results').addEventListener('click', () => {
        // ONLY send message
        fetch(`https://${GetParentResourceName()}/closeResults`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({})
        });
    });

    // Helper to close UI with Escape key
    document.onkeyup = function (data) {
        if (data.key === 'Escape') {
            // Only send the event if a menu is visible, let Lua handle the state change
            if (menuContainer.style.display === 'block' || resultsContainer.style.display === 'block') {
                fetch(`https://${GetParentResourceName()}/closeMenu`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                    body: JSON.stringify({})
                });
            }
        }
    };
});