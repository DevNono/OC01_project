FROM node:18.16.0-alpine as base

ENV NODE_ENV=production
WORKDIR /srv/app

RUN npm install -g pnpm

FROM base as development

COPY package.json pnpm-lock.yaml ./

RUN pnpm install --frozen-lockfile --production=false

COPY src ./src
COPY tsconfig.json ./tsconfig.json

RUN pnpm build

FROM base as production

COPY --from=development /srv/app/dist ./dist
COPY --from=development /srv/app/package.json /srv/app/pnpm-lock.yaml ./

# Prunes devDependencies
RUN pnpm install --production --ignore-scripts --prefer-offline

CMD pnpm start