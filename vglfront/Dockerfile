FROM node:16-alpine as builder

WORKDIR /usr/vglfront
COPY ./src src/
COPY *.json ./
RUN npm ci --progress=false && npm run build

FROM nginx:1.23-alpine

WORKDIR /usr/vglfront
ENV API_URL=${API_URL}
ENV TEST_API_URL=${TEST_API_URL}
COPY --from=builder /usr/vglfront/dist/video-games-library-front /usr/share/nginx/html
COPY ./server/docker/*.sh ./
RUN chmod +x ./serve.sh && \
    wget https://github.com/atkrad/wait4x/releases/download/v2.9.1/wait4x-linux-amd64.tar.gz && \
    tar -xvf wait4x-linux-amd64.tar.gz && \
    chmod +x ./wait4x
EXPOSE 80

ENTRYPOINT ["/usr/vglfront/serve.sh"]