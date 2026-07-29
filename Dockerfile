FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Cache dependency resolution separately so source-only edits do not invalidate pub packages.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# API_BASE_URL is injected into Dart at compile time because Flutter web is static once built.
# GOOGLE_MAPS_API_KEY serves two distinct consumers: the Dart side (Places /
# Geocoding HTTP calls) and the Maps JS SDK in index.html (map rendering).
ARG API_BASE_URL=/api/v1
ARG APP_BASE_URL=
ARG GOOGLE_MAPS_API_KEY=
RUN flutter build web --release --no-wasm-dry-run \
      --dart-define=API_BASE_URL=${API_BASE_URL} \
      --dart-define=APP_BASE_URL=${APP_BASE_URL} \
      --dart-define=GOOGLE_MAPS_API_KEY=${GOOGLE_MAPS_API_KEY} \
 && sed -i "s|__GOOGLE_MAPS_API_KEY__|${GOOGLE_MAPS_API_KEY}|g" build/web/index.html

FROM nginx:1.27-alpine

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
