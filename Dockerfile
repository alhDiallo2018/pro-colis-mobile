# syntax=docker/dockerfile:1

FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Cache dependency resolution separately so source-only edits do not invalidate pub packages.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# API_BASE_URL is injected into Dart at compile time because Flutter web is static once built.
ARG API_BASE_URL=http://localhost:8080
RUN flutter build web --release --no-wasm-dry-run --dart-define=API_BASE_URL=${API_BASE_URL}

FROM nginx:1.27-alpine

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
