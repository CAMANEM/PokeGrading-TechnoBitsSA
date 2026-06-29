FROM node:20-alpine
WORKDIR /app
RUN npm install mongodb
COPY upload_references.js .
CMD ["node", "upload_references.js"]
