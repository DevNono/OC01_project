/* eslint-disable import/first */
import dotenv from 'dotenv';
import { Server } from 'socket.io';
import http from 'http';
import app from './app';
import logger from './logger';
import websockets from './events';

const result = dotenv.config();
if (result.error) {
  dotenv.config({ path: '.env.example' });
}

const PORT = process.env.PORT || 3000;
const server = http.createServer(app);

// log app connections attempts
app.on('connection', () => {
  logger.info(`🔌 Connection`);
});

const wss = new Server(server, {
  cors: {
    origin: '*',
  },
});

websockets(wss);

server.listen(PORT, () => {
  logger.info(`🌏 Express server started at http://localhost:${PORT}`);
});
