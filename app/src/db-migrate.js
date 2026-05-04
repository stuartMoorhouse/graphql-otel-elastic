const pool = require('./db');

async function migrate() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS authors (
      id SERIAL PRIMARY KEY,
      name VARCHAR(255) NOT NULL,
      email VARCHAR(255) UNIQUE NOT NULL,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );
    CREATE TABLE IF NOT EXISTS posts (
      id SERIAL PRIMARY KEY,
      title VARCHAR(500) NOT NULL,
      content TEXT NOT NULL,
      author_id INTEGER REFERENCES authors(id),
      published_at TIMESTAMPTZ DEFAULT NOW()
    );
    CREATE TABLE IF NOT EXISTS comments (
      id SERIAL PRIMARY KEY,
      body TEXT NOT NULL,
      post_id INTEGER REFERENCES posts(id) ON DELETE CASCADE,
      author_id INTEGER REFERENCES authors(id),
      created_at TIMESTAMPTZ DEFAULT NOW()
    );
  `);

  const { rows } = await pool.query('SELECT COUNT(*) FROM authors');
  if (parseInt(rows[0].count) === 0) {
    await pool.query(`
      INSERT INTO authors (name, email) VALUES
        ('Alice Johnson', 'alice@example.com'),
        ('Bob Smith', 'bob@example.com');
    `);
    const { rows: authors } = await pool.query('SELECT id FROM authors');
    await pool.query(`
      INSERT INTO posts (title, content, author_id) VALUES
        ('Getting Started with GraphQL', 'GraphQL is a query language for APIs...', $1),
        ('OpenTelemetry for Node.js', 'OTel gives you distributed tracing...', $2);
    `, [authors[0].id, authors[1].id]);
  }

  console.log('Migration complete');
  await pool.end();
}

migrate().catch(err => { console.error(err); process.exit(1); });
