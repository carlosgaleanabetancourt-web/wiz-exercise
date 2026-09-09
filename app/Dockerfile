# Building the binary of the App
FROM golang:1.26 AS build

WORKDIR /go/src/tasky
COPY . .
RUN go get golang.org/x/crypto@latest golang.org/x/net@latest golang.org/x/text@latest && go mod tidy
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /go/src/tasky/tasky


FROM alpine:3.21 AS release

RUN adduser -D -u 1000 appuser
WORKDIR /app
COPY --from=build --chown=appuser:appuser /go/src/tasky/tasky .
COPY --from=build --chown=appuser:appuser /go/src/tasky/assets ./assets
COPY --chown=appuser:appuser wizexercise.txt .
EXPOSE 8080
USER 1000
ENTRYPOINT ["/app/tasky"]


