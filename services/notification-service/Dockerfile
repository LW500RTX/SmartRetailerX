# Stage 1: Build & Install dependencies
FROM node:20-alpine AS builder
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install

# Stage 2: Runtime image
FROM node:20-alpine
WORKDIR /usr/src/app
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY package*.json ./
COPY index.js ./

# Enforce security best practices by running as non-root user
USER node

CMD ["npm", "start"]
