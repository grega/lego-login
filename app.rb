require 'sinatra'
require 'sinatra/reloader' if development?
require 'json'
require 'digest'
require 'securerandom'

# enable sessions for user management
enable :sessions
set :session_secret, ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) }

# in-memory user store
# in production, use a database, but also don't put this into production :)
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
  <link rel="stylesheet" href="/style.css">
  <script src="https://cdn.jsdelivr.net/npm/@tensorflow/tfjs@4.10.0/dist/tf.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/@tensorflow-models/mobilenet@2.1.0/dist/mobilenet.min.js"></script>
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

<script src="/auth-common.js"></script>
<script src="/signup.js"></script>

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

<script src="/auth-common.js"></script>
<script src="/login.js"></script>

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
