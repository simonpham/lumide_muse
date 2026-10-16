/**
 * Main Orchestrator
 */

window.updateUI = function(state) {
    if (!state) return;
    
    try {
        if (state.title !== undefined) document.getElementById('title').textContent = state.title;
        if (state.subtitle !== undefined) document.getElementById('subtitle').textContent = state.subtitle;
        
        // Delegate to features
        if (window.playbackFeature) {
            window.playbackFeature.update(state);
        }

        if (state.lyrics !== undefined && window.lyricsFeature) {
            window.lyricsFeature.setLyrics(state.lyrics);
        }

        if (state.currentMillis !== undefined && window.lyricsFeature) {
            window.lyricsFeature.sync(state.currentMillis);
        }
    } catch (err) {
        console.error('Main UI Update Error:', err);
    }
};

document.addEventListener('DOMContentLoaded', () => {
    const playBtn = document.getElementById('play-btn');
    const nextBtn = document.getElementById('next-btn');
    const prevBtn = document.getElementById('prev-btn');
    const progressBar = document.getElementById('progress-bar');

    if (playBtn) playBtn.onclick = () => sendCommand('playPause');
    if (nextBtn) nextBtn.onclick = () => sendCommand('next');
    if (prevBtn) prevBtn.onclick = () => sendCommand('previous');

    if (progressBar) {
        progressBar.onclick = (e) => {
            const rect = progressBar.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const progress = Math.max(0, Math.min(1, x / rect.width));
            sendCommand('seek', progress);
        };
    }
});

// Signal readiness
window.onload = () => {
    setTimeout(() => {
        sendCommand('ready');
    }, 500);
};
