const { ApolloServer } = require('@apollo/server');
const { startStandaloneServer } = require('@apollo/server/standalone');
const typeDefs = require('./schema');
const resolvers = require('./resolvers');

const PORT = parseInt(process.env.PORT || '4000', 10);

async function main() {
  const server = new ApolloServer({ typeDefs, resolvers });
  const { url } = await startStandaloneServer(server, { listen: { port: PORT } });
  console.log(`GraphQL server ready at ${url}`);
}

main().catch(err => { console.error(err); process.exit(1); });
