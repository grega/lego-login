async function handleCapture() {
  const pattern = await capturePattern();
  if (pattern) {
    showStatus('Pattern captured. Click Log In to verify.', 'success');
    document.getElementById('captureBtn').style.display = 'none';
    document.getElementById('submitBtn').style.display = 'inline-block';
  }
}

async function handleSubmit(e) {
  e.preventDefault();
  
  const username = document.getElementById('username').value;
  
  if (!capturedPattern) {
    showStatus('Please capture your Lego first.', 'error');
    return;
  }
  
  try {
    const response = await fetch('/api/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        username: username,
        lego_pattern: capturedPattern
      })
    });
    
    const result = await response.json();
    
    if (result.success) {
      showStatus('Login successful. Redirecting...', 'success');
      setTimeout(() => window.location.href = '/dashboard', 1500);
    } else {
      showStatus(result.message, 'error');
      document.getElementById('captureBtn').style.display = 'inline-block';
      document.getElementById('submitBtn').style.display = 'none';
      capturedPattern = null;
    }
  } catch (err) {
    showStatus('An error occurred. Please try again.', 'error');
    console.error('Login error:', err);
  }
}

document.getElementById('captureBtn').addEventListener('click', handleCapture);
document.getElementById('loginForm').addEventListener('submit', handleSubmit);
initCamera('Camera ready - show your Lego password.');
