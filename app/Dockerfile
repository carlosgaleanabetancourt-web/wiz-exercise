# Building the binary of the App
FROM golang:1.26 AS build

WORKDIR /go/src/tasky
COPY . .
RUN go get golang.org/x/crypto@latest golang.org/x/net@latest golang.org/x/text@latest && go mod tidy
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /go/src/tasky/tasky


FROM alpine:3.21 AS release

WORKDIR /app
COPY --from=build  /go/src/tasky/tasky .
COPY --from=build  /go/src/tasky/assets ./assets
COPY wizexercise.txt .
EXPOSE 8080
ENTRYPOINT ["/app/tasky"]


