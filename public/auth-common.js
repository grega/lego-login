let model;
let capturedPattern = null;

async function initCamera(readyMessage) {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ 
      video: { facingMode: 'environment' } 
    });
    document.getElementById('video').srcObject = stream;
    
    // load MobileNet model for feature extraction
    model = await mobilenet.load();
    showStatus(readyMessage, 'info');
  } catch (err) {
    showStatus('Camera access denied. Please enable camera permissions.', 'error');
    console.error('Camera error:', err);
  }
}

async function capturePattern() {
  const video = document.getElementById('video');
  const canvas = document.getElementById('canvas');
  const ctx = canvas.getContext('2d');
  
  canvas.width = video.videoWidth;
  canvas.height = video.videoHeight;
  ctx.drawImage(video, 0, 0);
  
  try {
    // extract features using MobileNet
    const img = tf.browser.fromPixels(canvas);
    const predictions = await model.classify(img);
    const features = await model.infer(img, true).data();
    
    capturedPattern = {
      features: Array.from(features),
      predictions: predictions,
      timestamp: Date.now()
    };
    
    img.dispose();
    
    return capturedPattern;
  } catch (err) {
    showStatus('Failed to capture pattern. Please try again.', 'error');
    console.error('Capture error:', err);
    return null;
  }
}

function showStatus(message, type) {
  const status = document.getElementById('status');
  status.textContent = message;
  status.className = 'status ' + type;
}
