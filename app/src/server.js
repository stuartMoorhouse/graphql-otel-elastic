const express = require('express');
const { ApolloServer } = require('@apollo/server');
const { expressMiddleware } = require('@apollo/server/express4');
const { ApolloServerPluginLandingPageLocalDefault } = require('@apollo/server/plugin/landingPage/default');
const typeDefs = require('./schema');
const resolvers = require('./resolvers');

const PORT = parseInt(process.env.PORT || '4000', 10);

const BLOG_HTML = /* html */`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>GraphQL Blog</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: Georgia, serif; background: #f9f7f4; color: #1a1a1a; }
    header { background: #1a1a1a; color: #fff; padding: 2rem; }
    header h1 { font-size: 1.8rem; letter-spacing: -0.5px; }
    header p { color: #aaa; font-size: 0.9rem; margin-top: 0.3rem; font-family: monospace; }
    main { max-width: 780px; margin: 2.5rem auto; padding: 0 1.5rem; }
    #status { color: #888; font-size: 0.9rem; margin-bottom: 1.5rem; }
    article { background: #fff; border: 1px solid #e5e5e5; border-radius: 6px;
              padding: 1.8rem; margin-bottom: 1.5rem; }
    article h2 { font-size: 1.3rem; margin-bottom: 0.4rem; }
    .meta { font-size: 0.82rem; color: #888; margin-bottom: 1rem; font-family: monospace; }
    .content { line-height: 1.7; color: #333; white-space: pre-wrap; }
    .footer { margin-top: 1rem; font-size: 0.82rem; color: #aaa; font-family: monospace; }
    a { color: inherit; text-decoration: none; }
    a:hover { text-decoration: underline; }
  </style>
</head>
<body>
  <header>
    <h1>GraphQL Blog</h1>
    <p>Apollo Server 4 &nbsp;·&nbsp; OTel → Elastic Observability &nbsp;·&nbsp;
       <a href="/graphql" style="color:#ccc">GraphQL Sandbox ↗</a></p>
  </header>
  <main>
    <p id="status">Loading posts…</p>
    <div id="posts"></div>
  </main>
  <script>
    const QUERY = \`{
      posts {
        id title content publishedAt
        author { name }
        comments { id }
      }
    }\`;

    async function load() {
      const status = document.getElementById('status');
      const container = document.getElementById('posts');
      try {
        const res = await fetch('/graphql', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ query: QUERY }),
        });
        const { data, errors } = await res.json();
        if (errors) throw new Error(errors[0].message);

        status.textContent = data.posts.length + ' posts';
        container.innerHTML = data.posts.map(post => \`
          <article>
            <h2>\${esc(post.title)}</h2>
            <div class="meta">
              by \${esc(post.author.name)}
              &nbsp;·&nbsp; \${new Date(post.publishedAt).toLocaleDateString()}
              &nbsp;·&nbsp; \${post.comments.length} comment\${post.comments.length !== 1 ? 's' : ''}
            </div>
            <div class="content">\${esc(post.content)}</div>
          </article>
        \`).join('');
      } catch (err) {
        status.textContent = 'Error: ' + err.message;
      }
    }

    function esc(s) {
      return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
    }

    load();
  </script>
</body>
</html>`;

async function main() {
  const app = express();

  const server = new ApolloServer({
    typeDefs,
    resolvers,
    introspection: true,
    plugins: [ApolloServerPluginLandingPageLocalDefault({ embed: true })],
  });

  await server.start();

  app.get('/', (_req, res) => res.send(BLOG_HTML));
  app.use('/graphql', express.json(), expressMiddleware(server));

  app.listen(PORT, () => console.log(`Server ready at http://localhost:${PORT}/`));
}

main().catch(err => { console.error(err); process.exit(1); });
