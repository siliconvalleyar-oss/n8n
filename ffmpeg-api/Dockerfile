FROM node:18-alpine

RUN apk add --no-cache ffmpeg curl yt-dlp msttcorefonts-installer fontconfig ttf-dejavu && update-ms-fonts && fc-cache -f

WORKDIR /app
COPY package.json .
RUN npm install --production
COPY server.js .

EXPOSE 3000
CMD ["node", "server.js"]
