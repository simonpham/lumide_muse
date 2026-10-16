/**
 * Playback Feature
 */

function updatePlaybackUI(state) {
    if (state.isPlaying !== undefined) {
        const playIcon = document.getElementById('play-icon');
        if (playIcon) {
            if (state.isPlaying) {
                playIcon.innerHTML = '<path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/>';
            } else {
                playIcon.innerHTML = '<path d="M8 5v14l11-7z"/>';
            }
        }
    }

    if (state.progress !== undefined) {
        const fill = document.getElementById('progress-fill');
        if (fill) fill.style.width = (state.progress * 100) + '%';
    }

    if (state.currentTime !== undefined) {
        const el = document.getElementById('current-time');
        if (el) el.textContent = state.currentTime;
    }
    
    if (state.totalTime !== undefined) {
        const el = document.getElementById('total-time');
        if (el) el.textContent = state.totalTime;
    }
}

window.playbackFeature = {
    update: (state) => updatePlaybackUI(state)
};
