const { db, runQuery, allQuery } = require('./database');

// Seed script for testing - inserts a test todo
const seedDatabase = async () => {
  try {
    console.log('Seeding database with test data...');

    // Insert a test todo
    const result = await runQuery(
      'INSERT INTO todos (title, completed) VALUES (?, ?)',
      ['测试待办事项 - 这是第一条测试数据', 0]
    );

    console.log('Inserted test todo with ID:', result.id);

    // Fetch and display all todos
    const todos = await allQuery('SELECT * FROM todos');
    console.log('Current todos in database:');
    console.table(todos);

  } catch (error) {
    console.error('Seeding failed:', error.message);
  } finally {
    db.close((err) => {
      if (err) {
        console.error('Error closing database:', err.message);
      } else {
        console.log('Database connection closed');
      }
    });
  }
};

// Run seed if this script is executed directly
if (require.main === module) {
  seedDatabase();
}

module.exports = { seedDatabase };
