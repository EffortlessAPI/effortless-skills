# Rulebook Portal API — read-only Node server.
#
# The rulebook, skills/, and rulespeak/ directories are NOT baked into this
# image — they're bind-mounted read-only at runtime (see ../docker-compose.yml)
# so the portal always reflects whatever is currently on disk, without a
# rebuild, while the container image itself stays a pure, disposable artifact.
FROM node:20-alpine

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY . .

EXPOSE 5177

CMD ["node", "index.js"]
