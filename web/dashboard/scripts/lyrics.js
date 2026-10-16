/**
 * Lyrics Feature
 */

let currentLyrics = [];
let currentLineIndex = -1;

function renderLyrics() {
    try {
        const track = document.getElementById('lyrics-track');
        if (!track) return;
        
        track.innerHTML = '';
        
        if (!currentLyrics || currentLyrics.length === 0) {
            track.innerHTML = '<p class="lyric-line active">No lyrics available</p>';
            return;
        }

        currentLyrics.forEach((line, index) => {
            if (!line) return;
            const p = document.createElement('p');
            p.className = 'lyric-line';
            p.id = `lyric-${index}`;
            p.textContent = line.text || '';
            track.appendChild(p);
        });
        
        currentLineIndex = -1;
    } catch (err) {
        console.error('Render Lyrics Error:', err);
    }
}

function syncLyrics(millis) {
    try {
        if (!currentLyrics || currentLyrics.length === 0) return;

        let activeIndex = -1;
        for (let i = 0; i < currentLyrics.length; i++) {
            if (millis >= currentLyrics[i].time) {
                activeIndex = i;
            } else {
                break;
            }
        }

        if (activeIndex !== currentLineIndex && activeIndex !== -1) {
            if (currentLineIndex !== -1) {
                const prevLine = document.getElementById(`lyric-${currentLineIndex}`);
                if (prevLine) prevLine.classList.remove('active');
            }

            const currentLine = document.getElementById(`lyric-${activeIndex}`);
            if (currentLine) {
                currentLine.classList.add('active');
                
                const container = document.getElementById('lyrics-container');
                const track = document.getElementById('lyrics-track');
                
                if (container && track) {
                    const offset = currentLine.offsetTop - (container.offsetHeight / 2) + (currentLine.offsetHeight / 2);
                    track.style.transform = `translateY(${-offset}px)`;
                }
            }

            currentLineIndex = activeIndex;
        }
    } catch (err) {
        console.error('Sync Lyrics Error:', err);
    }
}

window.lyricsFeature = {
    setLyrics: (lyrics) => {
        currentLyrics = Array.isArray(lyrics) ? lyrics : [];
        renderLyrics();
    },
    sync: (millis) => syncLyrics(millis)
};
