FROM node:22-alpine AS build
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY tsconfig.json drizzle.config.ts ./
COPY src ./src

RUN npm run build

# `compose run --rm migrate` uses this stage; --force runs db:push non-interactively (no TTY).
CMD ["npm", "run", "db:push", "--", "--force"]

FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production

COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY --from=build /app/dist ./dist

# Own the dir as `node` so the mounted volume inherits write access for the non-root runtime user.
RUN mkdir -p /app/uploads && chown -R node:node /app/uploads

USER node
EXPOSE 3000
CMD ["node", "dist/index.js"]
