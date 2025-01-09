const express = require('express');
const path = require('path');

const app = express();
const port = process.env.PORT || 3008;


// Serve static files from the Flutter web build directory
app.use(express.static(path.join(__dirname, 'build/web')));

// Catch-all route to serve index.html for any other routes
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'build/web', 'index.html'));
});

// Start the server
app.listen(port, () => {
  console.log(`Server is running on http://localhost:${port}`);
});

