FROM alpine

MAINTAINER InnoLab-Team <inno.lab.prague@gmail.com>

# Install dependencies
RUN apk update && apk upgrade \
  && apk add redis \
  && apk add nodejs \
  && apk add --update nodejs nodejs-npm \
  && apk add curl \
  && npm install -g coffeescript \
  && npm install -g yo generator-hubot \
  && rm -rf /var/cache/apk/*

# Create hubot user
RUN	adduser -h /hubot -s /bin/bash -S hubot

# Log in as hubot user and change directory
USER	hubot
WORKDIR /hubot

# Install hubot
RUN yo hubot --owner="InnoLab-Team <inno.lab.prague@gmail.com>" \ 
      --name="Mergebot" \
      --description="Automated GitHub bot" \
      --defaults

# Copy over necessary configurations
ADD external-scripts.json /hubot/
ADD responses /hubot/responses
ADD scripts/bbom-cleaner.coffee /hubot/scripts
ADD package.json /hubot/

# Install dependencies
RUN npm install

# Set environment
ADD env.sh /hubot

# Run command
CMD ["/bin/sh", "-c", ". ./env.sh; bin/hubot --adapter slack"]
