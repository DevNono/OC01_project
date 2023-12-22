import fs from 'fs';
import path from 'path';
import { Credentials, Device, Event } from './types';
import { Secret } from './lib/secret';

const dbPath = path.resolve(__dirname, '../db/data.json');

const getDevice = (serial: string): Device | undefined => {
  const db = JSON.parse(fs.readFileSync(dbPath, 'utf8'));
  return db.find((device: Device) => device.serial === serial);
};

const getDeviceEvents = (serial: string): Event[] | undefined => {
  const device = getDevice(serial);
  return device?.events;
};

const registerDevice = async (device: Device) => {
  const db = JSON.parse(fs.readFileSync(dbPath, 'utf8'));
  const secret = await Secret.hashPassword(device.hashedSecret);
  db.push({ ...device, hashedSecret: secret });
  fs.writeFileSync(dbPath, JSON.stringify(db));
};

const addEvent = (serial: string, event: Event) => {
  const db = JSON.parse(fs.readFileSync(dbPath, 'utf8'));
  const deviceIndex = db.findIndex((device: Device) => device.serial === serial);
  db[deviceIndex].events.push(event);
  fs.writeFileSync(dbPath, JSON.stringify(db));
};

const deleteDevice = (serial: string) => {
  const db = JSON.parse(fs.readFileSync(dbPath, 'utf8'));
  const deviceIndex = db.findIndex((device: Device) => device.serial === serial);
  db.splice(deviceIndex, 1);
  fs.writeFileSync(dbPath, JSON.stringify(db));
};

const checkCredentials = async ({ serial, secret }: Credentials): Promise<boolean> => {
  const db = JSON.parse(fs.readFileSync(dbPath, 'utf8'));
  const device = db.find((d: Device) => d.serial === serial);

  if (!device) return false;

  return Secret.comparePassword(device.hashedSecret, secret);
};

const setConnected = (deviceSerial: string, connected: boolean) => {
  const db = JSON.parse(fs.readFileSync(dbPath, 'utf8'));
  const deviceIndex = db.findIndex((device: Device) => device.serial === deviceSerial);
  db[deviceIndex].connected = connected;
  fs.writeFileSync(dbPath, JSON.stringify(db));
};

const setActivated = (deviceSerial: string, activated: boolean) => {
  const db = JSON.parse(fs.readFileSync(dbPath, 'utf8'));
  const deviceIndex = db.findIndex((device: Device) => device.serial === deviceSerial);
  db[deviceIndex].activated = activated;
  fs.writeFileSync(dbPath, JSON.stringify(db));
};

export {
  getDevice,
  getDeviceEvents,
  registerDevice,
  addEvent,
  deleteDevice,
  checkCredentials,
  setConnected,
  setActivated,
};
