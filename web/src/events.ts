import { Server, Socket } from 'socket.io';
import logger from './logger';
import { addEvent, checkCredentials, getDevice, getDeviceEvents, registerDevice, setConnected } from './db';
import { Credentials, DeviceType } from './types';

const socketAssignements = new Map();

const response = (data: object, error: boolean) => ({
  data,
  status: error,
});

const checkAuth = async (s: Socket, event: string, credentials: Credentials) => {
  if (event === 'login' && !(await checkCredentials(credentials))) {
    logger.error(`Invalid credentials`);
    s.emit(`callback-${event}`, response({ message: 'Invalid credentials' }, true));
    return false;
  }

  if (event !== 'login' && !socketAssignements.has(s.id)) {
    logger.error(`Not logged in`);
    s.emit(`callback-${event}`, response({ message: 'Not logged in' }, true));
    return false;
  }

  return true;
};

const checkConnected = (s: Socket, event: string, serial: string) => {
  if (!getDevice(serial).connected) {
    logger.error(`Device [${serial}] not connected`);
    logger.error(`callback-${event}`);
    s.emit(`callback-${event}`, response({ message: 'Device not connected' }, true));
    return false;
  }

  return true;
};

const dataToCredentials = (data: any): Credentials => ({
  serial: data.serial,
  secret: data.secret,
});

const websockets = (wss: Server) => {
  wss.on('connection', (s: Socket) => {
    logger.info(`🔌 Connection`);
    s.send('Connected');

    s.on('register', async (data: any) => {
      if (data.type === DeviceType.app) {
        s.emit('callback-register', response({ message: 'Not a device' }, true));
        return;
      }

      if (await getDevice(data.serial)) {
        s.emit('callback-register', response({ message: 'Already registered' }, true));
        return;
      }

      registerDevice({
        serial: data.serial,
        hashedSecret: data.secret,
        connected: false,
        activated: true,
        events: [],
      });

      s.join(`${data.serial}-${data.type}`);
      s.emit('callback-register', response({ message: 'Registered successfully' }, false));

      logger.info(`${DeviceType.device} [${data.serial}] registered successfully`);
    });

    s.on('login', async (data: any) => {
      if (socketAssignements.has(s.id)) {
        s.emit('callback-login', response({ message: 'Already logged in' }, true));
        return;
      }

      if (!(await checkAuth(s, 'login', dataToCredentials(data)))) return;

      socketAssignements.set(s.id, {
        serial: data.serial,
        type: data.type,
      });

      s.join(`${data.serial}-${data.type}`);

      if (data.type === DeviceType.device) {
        s.emit(
          'callback-login',
          response({ message: 'Logged in successfully', activated: getDevice(data.serial).activated }, false),
        );
        setConnected(data.serial, true);
        wss
          .to(`${data.serial}-${DeviceType.app}`)
          .emit('statuschanged', { serial: data.serial, connected: true, activated: getDevice(data.serial).activated });
      } else
        s.emit(
          'callback-login',
          response({ message: 'Logged in successfully', device: getDevice(data.serial) }, false),
        );

      logger.info(`${data.type} [${data.serial}] logged in successfully`);
    });

    s.on('getevents', async (data: any) => {
      if (!(await checkAuth(s, 'getevents', dataToCredentials(data)))) return;
      const { serial, type } = socketAssignements.get(s.id);

      s.emit('callback-getevents', response(getDeviceEvents(serial), false));

      logger.info(`${type} [${serial}] fetched events successfully`);
    });

    s.on('event', async (data: any) => {
      if (!(await checkAuth(s, 'event', dataToCredentials(data)))) return;
      const { serial, type } = socketAssignements.get(s.id);

      if (type === DeviceType.app) {
        s.emit('callback-event', response({ message: 'Not a device' }, true));
        return;
      }

      addEvent(serial, data);

      s.to(`${serial}-${DeviceType.app}`).emit('event', response(data, false));
      s.emit('callback-event', response({ message: 'Event sent successfully' }, false));

      logger.info(`${DeviceType.device} [${serial}] sent event successfully`);
    });

    s.on('changepin', async (data: any) => {
      if (!(await checkAuth(s, 'changepin', dataToCredentials(data)))) return;
      const { serial, type } = socketAssignements.get(s.id);

      if (!checkConnected(s, 'changepin', serial)) return;

      // get DeviceType.app if device is device and vice versa
      const deviceType = type === DeviceType.app ? DeviceType.device : DeviceType.app;
      if (data.callback === true)
        s.to(`${serial}-${deviceType}`).emit(
          'callback-changepin',
          response({ message: 'Pin changed successfully' }, false),
        );
      else s.to(`${serial}-${deviceType}`).emit('changepin', response({ pin: data.pin }, false));

      logger.info(`${type} [${serial}] changed pin successfully`);
    });

    s.on('unpair', async (data: any) => {
      if (!(await checkAuth(s, 'unpair', dataToCredentials(data)))) return;
      const { serial, type } = socketAssignements.get(s.id);

      // if device is offline, abort
      if (!checkConnected(s, 'unpair', serial)) return;

      // get DeviceType.app if device is device and vice versa
      const deviceType = type === DeviceType.app ? DeviceType.device : DeviceType.app;
      if (data.callback === true)
        s.to(`${serial}-${deviceType}`).emit('callback-unpair', response({ message: 'Unpaired successfully' }, false));
      else s.to(`${serial}-${deviceType}`).emit('unpair', { serial, connected: data.connected });

      logger.info(`${type} [${serial}] unpaired successfully`);
    });

    s.on('statuschanged', async (data: any) => {
      if (!(await checkAuth(s, 'statuschanged', dataToCredentials(data)))) return;

      const { serial, type } = socketAssignements.get(s.id);

      // if device is offline, abort
      if (!checkConnected(s, 'statuschanged', serial)) return;

      // get DeviceType.app if device is device and vice versa
      const deviceType = type === DeviceType.app ? DeviceType.device : DeviceType.app;
      if (data.callback === true)
        s.to(`${serial}-${deviceType}`).emit(
          'callback-statuschanged',
          response({ message: 'Status changed successfully' }, false),
        );
      else
        s.to(`${serial}-${deviceType}`).emit('statuschanged', {
          serial,
          connected: data.connected !== undefined ? data.connected : getDevice(serial).connected,
          activated: data.activated !== undefined ? data.activated : getDevice(serial).activated,
        });

      logger.info(`${DeviceType.device} [${serial}] changed status successfully`);
    });

    s.on('disconnect', () => {
      logger.info(`🔌 Disconnected`);
      if (!socketAssignements.has(s.id)) return;

      const { serial, type } = socketAssignements.get(s.id);
      logger.info(`${type} [${serial}] disconnected`);
      if (type === DeviceType.app) return;

      setConnected(serial, false);
      wss
        .to(`${serial}-${DeviceType.app}`)
        .emit('statuschanged', { serial, connected: false, activated: getDevice(serial).activated });
    });
  });
};

export default websockets;
