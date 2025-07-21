const express = require('express');
const path = require('path');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 4000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Health check
app.get('/health', (req, res) => {
    res.json({ 
        status: 'ok', 
        service: 'admin-dashboard',
        timestamp: new Date().toISOString() 
    });
});

// Servir dashboard na raiz
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// API routes (proxy para Control API)
app.get('/api/*', (req, res) => {
    res.json({
        message: 'Use Control API directly at :3001' + req.path,
        controlApiUrl: `http://localhost:3001${req.path}`
    });
});

app.listen(PORT, () => {
    console.log(`🎛️  Admin Dashboard rodando na porta ${PORT}`);
    console.log(`📊 Dashboard: http://localhost:${PORT}`);
});