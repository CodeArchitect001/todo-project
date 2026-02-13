const express = require('express');
const cors = require('cors');
const { runQuery, getQuery } = require('./database');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', message: 'Server is running' });
});

// Create a new todo
app.post('/api/todos', async (req, res) => {
  try {
    const { title } = req.body;

    if (!title || typeof title !== 'string' || title.trim() === '') {
      return res.status(400).json({ error: 'Title is required and must be a non-empty string' });
    }

    const sql = 'INSERT INTO todos (title, completed) VALUES (?, ?)';
    const result = await runQuery(sql, [title.trim(), false]);

    // Fetch the created todo
    const newTodo = await getQuery('SELECT * FROM todos WHERE id = ?', [result.id]);

    res.status(201).json(newTodo);
  } catch (error) {
    console.error('Error creating todo:', error);
    res.status(500).json({ error: 'Failed to create todo' });
  }
});

app.listen(PORT, () => {
  console.log('Server is running on port ' + PORT);
});
