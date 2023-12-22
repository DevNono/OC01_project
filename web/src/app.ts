import compression from 'compression';
import express, { Request, Response, NextFunction } from 'express';
import routes from './routes';
import logger from './logger';

const app = express();

function logResponseTime(req: Request, res: Response, next: NextFunction) {
  const startHrTime = process.hrtime();

  res.on('finish', () => {
    const elapsedHrTime = process.hrtime(startHrTime);
    const elapsedTimeInMs = elapsedHrTime[0] * 1000 + elapsedHrTime[1] / 1e6;
    const message = `${req.method} ${res.statusCode} ${elapsedTimeInMs}ms\t${req.path}`;
    logger.log({
      level: 'debug',
      message,
      consoleLoggerOptions: { label: 'API' },
    });
  });

  next();
}

app.use(logResponseTime);

app.use(compression());

app.use(routes);

// Error handler
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  logger.error(err.message, { consoleLoggerOptions: { label: 'API' } });
  res.status(500).send('Something broke!');
  next(err);
});

process.on('uncaughtException', (err) => {
  logger.error(err.message, { consoleLoggerOptions: { label: 'API' } });
  process.exit(1);
});

export default app;
