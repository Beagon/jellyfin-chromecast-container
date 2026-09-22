FROM node:24-slim AS fetch
ARG TAG=v1.3.0
WORKDIR /tmp
ADD --unpack https://api.github.com/repos/jellyfin/jellyfin-chromecast/tarball/refs/tags/${TAG} /tmp/

FROM node:24-slim AS build
WORKDIR /app
COPY --from=fetch /tmp/jellyfin-jellyfin-chromecast-*/. /app/
RUN npm ci && npm run build   # outputs to /app/dist

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
