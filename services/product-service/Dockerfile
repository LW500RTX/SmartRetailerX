# Stage 1: Build & Install production dependencies
FROM node:20-alpine AS builder
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install

# Stage 2: Minimal runtime image
FROM node:20-alpine
WORKDIR /usr/src/app
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY package*.json ./
COPY index.js ./

# Enforce security best practices by running as non-root user
USER node
EXPOSE 3000

CMD ["npm", "start"]
