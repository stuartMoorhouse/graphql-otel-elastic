const { gql } = require('graphql-tag');

module.exports = gql`
  type Author {
    id: ID!
    name: String!
    email: String!
    posts: [Post!]!
  }

  type Post {
    id: ID!
    title: String!
    content: String!
    author: Author!
    comments: [Comment!]!
    publishedAt: String!
  }

  type Comment {
    id: ID!
    body: String!
    author: Author!
    post: Post!
    createdAt: String!
  }

  type Query {
    posts: [Post!]!
    post(id: ID!): Post
    authors: [Author!]!
    author(id: ID!): Author
  }

  type Mutation {
    createPost(title: String!, content: String!, authorId: ID!): Post!
    createComment(body: String!, postId: ID!, authorId: ID!): Comment!
  }
`;
