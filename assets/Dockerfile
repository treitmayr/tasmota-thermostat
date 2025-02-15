FROM node:22

ENV NODE_ENV production

WORKDIR /data

RUN npm install -g npm
RUN npm install -g lv_font_conv

ENTRYPOINT ["lv_font_conv"]
