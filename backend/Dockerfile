# syntax=docker/dockerfile:1

# ---- build stage -----------------------------------------------------------
FROM node:20-alpine AS build
WORKDIR /app

# better-sqlite3 ships a prebuilt binary per platform, but install toolchain
# here so the native module can fall back to compiling if needed.
RUN apk add --no-cache python3 make g++

COPY package*.json ./
RUN npm ci --omit=dev

# ---- runtime stage ---------------------------------------------------------
FROM node:20-alpine
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000
ENV DATABASE_FILE=/data/finance.db

RUN apk add --no-cache tini

COPY --from=build /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src
COPY jsconfig.json ./

# The database lives on a mounted volume so it survives redeploys.
RUN mkdir -p /data && chown -R node:node /data /app
VOLUME ["/data"]

USER node
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "src/server.js"]