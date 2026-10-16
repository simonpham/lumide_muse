/**
 * Lumide Dashboard JS Bridge
 */

const lumide = {
    postMessage: (message) => {
        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
            window.flutter_inappwebview.callHandler('postMessage', JSON.stringify(message));
        }
    }
};

function sendCommand(command, value = null) {
    lumide.postMessage({ command, value });
}

// Receive messages from the plugin
window.addEventListener('message', event => {
    let data = event.data;
    
    if (typeof data === 'string') {
        try {
            data = JSON.parse(data);
        } catch (e) {
            return;
        }
    }

    if (data.type === 'updateState') {
        if (window.updateUI) {
            window.updateUI(data.state);
        }
    }
});
