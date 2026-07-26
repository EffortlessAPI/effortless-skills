# Rulebook Portal web UI — static Vite SPA served by nginx, which also
# reverse-proxies /api/* to the api container so the browser only ever talks
# to one origin (this container).
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
