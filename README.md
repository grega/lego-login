# Lego Login

An authentication system using Lego as a (visual) password.

To be clear, this is a terrible idea and should not be used anywhere near production.

https://github.com/user-attachments/assets/a2cc2313-b21b-44c7-b8ac-533b61b0ae8d

## Overview

Users authenticate by capturing images of their unique Lego constructions instead of text passwords. The system uses TensorFlow.js with MobileNet to extract image features and compares them using cosine similarity.

## Setup

Install dependencies:
```bash
bundle install
```

Set session secret (optional):
```bash
export SESSION_SECRET=your_secret_here
```

Run the server:
```bash
ruby app.rb
```

Visit `http://localhost:4567`

## How it works

- Create an account with a username and capture your Lego creation as a password
- Log in: Show the same Lego creation to authenticate
- Uses cosine similarity (85% threshold) on image feature vectors

Looking at the output from TensorFlow / MobileNet is quite entertaining; it has a guess at what the image is. "Great Dane"? is my favourite so far.
