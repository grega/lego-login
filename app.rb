require 'sinatra'
require 'sinatra/reloader' if development?
require 'json'
require 'digest'
require 'securerandom'

# enable sessions for user management
enable :sessions
set :session_secret, ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) }

# in-memory user store (in production, use a database)
USERS = {}

helpers do
  def logged_in?
    !session[:username].nil?
  end

  def current_user
    session[:username]
  end
end

# Routes
get '/' do
  if logged_in?
    redirect '/dashboard'
  else
    erb :index
  end
end

get '/signup' do
  redirect '/dashboard' if logged_in?
  erb :signup
end

get '/login' do
  redirect '/dashboard' if logged_in?
  erb :login
end

get '/dashboard' do
  redirect '/login' unless logged_in?
  erb :dashboard
end

post '/api/signup' do
  content_type :json
  data = JSON.parse(request.body.read)
  
  username = data['username']
  lego_pattern = data['lego_pattern']
  
  if username.nil? || username.empty?
    return { success: false, message: 'Username is required' }.to_json
  end
  
  if USERS.key?(username)
    return { success: false, message: 'Username already exists' }.to_json
  end

  # store user with hashed pattern
  USERS[username] = {
    pattern_hash: Digest::SHA256.hexdigest(lego_pattern.to_json),
    pattern_data: lego_pattern
  }
  
  session[:username] = username
  { success: true, message: 'Account created successfully' }.to_json
end

post '/api/login' do
  content_type :json
  data = JSON.parse(request.body.read)
  
  username = data['username']
  lego_pattern = data['lego_pattern']
  
  if !USERS.key?(username)
    return { success: false, message: 'Invalid credentials' }.to_json
  end
  
  stored_pattern = USERS[username][:pattern_data]
  
  # compare patterns (simplified - in production, use more sophisticated matching)
  if compare_patterns(stored_pattern, lego_pattern)
    session[:username] = username
    { success: true, message: 'Login successful' }.to_json
  else
    { success: false, message: 'Invalid Lego' }.to_json
  end
end

post '/logout' do
  session.clear
  redirect '/'
end

def compare_patterns(stored, provided)
  return false if stored.nil? || provided.nil?
  
  # simple similarity check - compares feature vectors
  # in production, use more sophisticated image matching
  stored_features = stored['features'] || []
  provided_features = provided['features'] || []
  
  return false if stored_features.empty? || provided_features.empty?
  
  similarity = cosine_similarity(stored_features, provided_features)
  similarity > 0.85 # 85% similarity threshold
end

def cosine_similarity(a, b)
  return 0.0 if a.length != b.length
  
  dot_product = a.zip(b).map { |x, y| x * y }.sum
  magnitude_a = Math.sqrt(a.map { |x| x**2 }.sum)
  magnitude_b = Math.sqrt(b.map { |x| x**2 }.sum)
  
  return 0.0 if magnitude_a == 0 || magnitude_b == 0
  
  dot_product / (magnitude_a * magnitude_b)
end

__END__

@@ layout
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Lego Authentication</title>
  <script src="https://cdn.jsdelivr.net/npm/@tensorflow/tfjs@4.10.0/dist/tf.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/@tensorflow-models/mobilenet@2.1.0/dist/mobilenet.min.js"></script>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
      display: flex;
      justify-content: center;
      align-items: center;
    }
    
    .container {
      background: white;
      border-radius: 20px;
      box-shadow: 0 20px 60px rgba(0,0,0,0.3);
      padding: 40px;
      max-width: 500px;
      width: 90%;
    }
    
    h1, h2 {
      color: #333;
      margin-bottom: 30px;
      text-align: center;
    }
    
    .form-group {
      margin-bottom: 20px;
    }
    
    label {
      display: block;
      margin-bottom: 8px;
      color: #555;
      font-weight: 500;
    }
    
    input[type="text"], input[type="password"] {
      width: 100%;
      padding: 12px;
      border: 2px solid #e0e0e0;
      border-radius: 8px;
      font-size: 16px;
      transition: border-color 0.3s;
    }
    
    input[type="text"]:focus, input[type="password"]:focus {
      outline: none;
      border-color: #667eea;
    }
    
    .btn {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      border: none;
      padding: 12px 30px;
      border-radius: 8px;
      font-size: 16px;
      font-weight: 600;
      cursor: pointer;
      transition: transform 0.2s, box-shadow 0.2s;
      display: inline-block;
      text-decoration: none;
      margin-right: 10px;
    }
    
    .btn:hover {
      transform: translateY(-2px);
      box-shadow: 0 10px 20px rgba(102, 126, 234, 0.4);
    }
    
    .btn-secondary {
      background: #f0f0f0;
      color: #333;
    }
    
    .btn-secondary:hover {
      box-shadow: 0 10px 20px rgba(0, 0, 0, 0.1);
    }
    
    .video-container {
      position: relative;
      margin: 20px 0;
      border-radius: 12px;
      overflow: hidden;
      background: #000;
    }
    
    #video {
      width: 100%;
      display: block;
      border-radius: 12px;
    }
    
    #canvas {
      display: none;
    }
    
    .camera-controls {
      margin: 20px 0;
      text-align: center;
    }
    
    .status {
      padding: 10px;
      border-radius: 8px;
      margin: 15px 0;
      text-align: center;
      display: none;
    }
    
    .status.success {
      background: #d4edda;
      color: #155724;
      border: 1px solid #c3e6cb;
      display: block;
    }
    
    .status.error {
      background: #f8d7da;
      color: #721c24;
      border: 1px solid #f5c6cb;
      display: block;
    }
    
    .status.info {
      background: #d1ecf1;
      color: #0c5460;
      border: 1px solid #bee5eb;
      display: block;
    }
    
    .links {
      text-align: center;
      margin-top: 20px;
    }
    
    .links a {
      color: #667eea;
      text-decoration: none;
      font-weight: 500;
    }
    
    .links a:hover {
      text-decoration: underline;
    }
    
    .dashboard {
      text-align: center;
    }
    
    .username-display {
      font-size: 24px;
      color: #667eea;
      margin: 20px 0;
    }
  </style>
</head>
<body>
  <div class="container">
    <%= yield %>
  </div>
</body>
</html>

@@ index
<h1>Lego Authentication</h1>
<p style="text-align: center; color: #666; margin-bottom: 30px;">
  Use your unique Lego creation as your password
</p>
<div style="text-align: center;">
  <a href="/signup" class="btn">Create Account</a>
  <a href="/login" class="btn btn-secondary">Log In</a>
</div>

@@ signup
<h2>Create Account</h2>
<form id="signupForm">
  <div class="form-group">
    <label for="username">Username</label>
    <input type="text" id="username" name="username" required>
  </div>
  
  <div class="form-group">
    <label>Lego Password</label>
    <p style="color: #666; font-size: 14px; margin-bottom: 10px;">
      Show your Lego creation to the camera, this will be your visual password.
    </p>
    <div class="video-container">
      <video id="video" autoplay></video>
      <canvas id="canvas"></canvas>
    </div>
  </div>
  
  <div id="status" class="status"></div>
  
  <div class="camera-controls">
    <button type="button" id="captureBtn" class="btn">Capture Lego</button>
    <button type="submit" class="btn btn-secondary" style="display: none;" id="submitBtn">Create Account</button>
  </div>
</form>

<div class="links">
  <a href="/login">Already have an account? Log in</a>
</div>

<script>
let model;
let capturedPattern = null;

async function initCamera() {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ 
      video: { facingMode: 'environment' } 
    });
    document.getElementById('video').srcObject = stream;
    
    // Load MobileNet model for feature extraction
    model = await mobilenet.load();
    showStatus('Camera ready. Position your Lego creation and click capture.', 'info');
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
    
    showStatus('Lego captured successfully', 'success');
    document.getElementById('captureBtn').style.display = 'none';
    document.getElementById('submitBtn').style.display = 'inline-block';
  } catch (err) {
    showStatus('Failed to capture pattern. Please try again.', 'error');
    console.error('Capture error:', err);
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
    const response = await fetch('/api/signup', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        username: username,
        lego_pattern: capturedPattern
      })
    });
    
    const result = await response.json();
    
    if (result.success) {
      showStatus('Account created. Redirecting...', 'success');
      setTimeout(() => window.location.href = '/dashboard', 1500);
    } else {
      showStatus(result.message, 'error');
    }
  } catch (err) {
    showStatus('An error occurred. Please try again.', 'error');
    console.error('Signup error:', err);
  }
}

function showStatus(message, type) {
  const status = document.getElementById('status');
  status.textContent = message;
  status.className = 'status ' + type;
}

document.getElementById('captureBtn').addEventListener('click', capturePattern);
document.getElementById('signupForm').addEventListener('submit', handleSubmit);

// Initialize camera on load
initCamera();
</script>

@@ login
<h2>Log In</h2>
<form id="loginForm">
  <div class="form-group">
    <label for="username">Username</label>
    <input type="text" id="username" name="username" required>
  </div>
  
  <div class="form-group">
    <label>Show Your Lego Password</label>
    <p style="color: #666; font-size: 14px; margin-bottom: 10px;">
      Show the same Lego creation you used during signup.
    </p>
    <div class="video-container">
      <video id="video" autoplay></video>
      <canvas id="canvas"></canvas>
    </div>
  </div>
  
  <div id="status" class="status"></div>
  
  <div class="camera-controls">
    <button type="button" id="captureBtn" class="btn">Verify Lego</button>
    <button type="submit" class="btn btn-secondary" style="display: none;" id="submitBtn">Log In</button>
  </div>
</form>

<div class="links">
  <a href="/signup">Need an account? Sign up</a>
</div>

<script>
let model;
let capturedPattern = null;

async function initCamera() {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ 
      video: { facingMode: 'environment' } 
    });
    document.getElementById('video').srcObject = stream;
    
    model = await mobilenet.load();
    showStatus('Camera ready - show your Lego password.', 'info');
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
    const img = tf.browser.fromPixels(canvas);
    const predictions = await model.classify(img);
    const features = await model.infer(img, true).data();
    
    capturedPattern = {
      features: Array.from(features),
      predictions: predictions,
      timestamp: Date.now()
    };
    
    img.dispose();
    
    showStatus('Pattern captured. Click Log In to verify.', 'success');
    document.getElementById('captureBtn').style.display = 'none';
    document.getElementById('submitBtn').style.display = 'inline-block';
  } catch (err) {
    showStatus('Failed to capture pattern. Please try again.', 'error');
    console.error('Capture error:', err);
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

function showStatus(message, type) {
  const status = document.getElementById('status');
  status.textContent = message;
  status.className = 'status ' + type;
}

document.getElementById('captureBtn').addEventListener('click', capturePattern);
document.getElementById('loginForm').addEventListener('submit', handleSubmit);

initCamera();
</script>

@@ dashboard
<div class="dashboard">
  <h1>Welcome</h1>
  <div class="username-display">
    Logged in as: <strong><%= current_user %></strong>
  </div>
  <p style="color: #666; margin: 20px 0;">
    You successfully authenticated using your Lego.
  </p>
  <form action="/logout" method="post" style="margin-top: 30px;">
    <button type="submit" class="btn btn-secondary">Log Out</button>
  </form>
</div>
