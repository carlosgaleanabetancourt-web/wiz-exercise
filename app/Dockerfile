# Building the binary of the App
FROM golang:1.26.8-alpine AS build

WORKDIR /go/src/tasky
COPY . .
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /go/src/tasky/tasky


FROM alpine:3.24 AS release

RUN apk upgrade --no-cache && adduser -D -u 1000 appuser
WORKDIR /app
COPY --from=build --chown=appuser:appuser /go/src/tasky/tasky .
COPY --from=build --chown=appuser:appuser /go/src/tasky/assets ./assets
COPY --chown=appuser:appuser wizexercise.txt .
EXPOSE 8080
USER 1000
ENTRYPOINT ["/app/tasky"]


