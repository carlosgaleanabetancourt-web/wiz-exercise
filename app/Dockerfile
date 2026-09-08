# Building the binary of the App
FROM golang:1.26 AS build

WORKDIR /go/src/tasky
COPY . .
RUN go get golang.org/x/crypto@v0.55.0 golang.org/x/net@v0.57.0 golang.org/x/text@v0.39.0 && go mod tidy
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /go/src/tasky/tasky


FROM alpine:3.21 AS release

WORKDIR /app
COPY --from=build  /go/src/tasky/tasky .
COPY --from=build  /go/src/tasky/assets ./assets
COPY wizexercise.txt .
EXPOSE 8080
ENTRYPOINT ["/app/tasky"]


