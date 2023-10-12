FROM klakegg/hugo:ext-alpine AS builder

WORKDIR /src
COPY . .

RUN hugo --minify

FROM nginx:1.25.2-alpine

COPY --from=builder /src/public /usr/share/nginx/html

EXPOSE 80