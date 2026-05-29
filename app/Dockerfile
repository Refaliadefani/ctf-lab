FROM node:18-alpine

WORKDIR /usr/src/app

COPY package.json ./
RUN npm install --production

COPY . .

# Create log directory
RUN mkdir -p /opt/admin/logs

EXPOSE 3000

CMD ["node", "server.js"]
