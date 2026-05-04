const pool = require('./db');

module.exports = {
  Query: {
    posts: () => pool.query('SELECT * FROM posts ORDER BY published_at DESC').then(r => r.rows),
    post: (_, { id }) => pool.query('SELECT * FROM posts WHERE id = $1', [id]).then(r => r.rows[0] ?? null),
    authors: () => pool.query('SELECT * FROM authors').then(r => r.rows),
    author: (_, { id }) => pool.query('SELECT * FROM authors WHERE id = $1', [id]).then(r => r.rows[0] ?? null),
  },
  Post: {
    author: (post) => pool.query('SELECT * FROM authors WHERE id = $1', [post.author_id]).then(r => r.rows[0]),
    comments: (post) => pool.query('SELECT * FROM comments WHERE post_id = $1', [post.id]).then(r => r.rows),
    publishedAt: (post) => post.published_at,
  },
  Comment: {
    author: (comment) => pool.query('SELECT * FROM authors WHERE id = $1', [comment.author_id]).then(r => r.rows[0]),
    post: (comment) => pool.query('SELECT * FROM posts WHERE id = $1', [comment.post_id]).then(r => r.rows[0]),
    createdAt: (comment) => comment.created_at,
  },
  Mutation: {
    createPost: async (_, { title, content, authorId }) => {
      const { rows } = await pool.query(
        'INSERT INTO posts (title, content, author_id) VALUES ($1, $2, $3) RETURNING *',
        [title, content, authorId]
      );
      return rows[0];
    },
    createComment: async (_, { body, postId, authorId }) => {
      const { rows } = await pool.query(
        'INSERT INTO comments (body, post_id, author_id) VALUES ($1, $2, $3) RETURNING *',
        [body, postId, authorId]
      );
      return rows[0];
    },
  },
};
