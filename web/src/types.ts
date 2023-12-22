export interface Credentials {
  serial: string;
  secret: string;
}

export interface RegisterEvent {
  event: string;
  data: unknown;
  credentials: Credentials;
}

export interface Event {
  name: string;
  type: string;
  date: number;
}

export interface Device {
  serial: string;
  hashedSecret: string;
  connected: boolean;
  activated: boolean;
  events: Event[];
}

export enum DeviceType {
  app = 'app',
  device = 'device',
}

export interface RegisterDevice extends Credentials {
  type: DeviceType;
}
