# Trust backend — production image (keyingi bosqich: VPS/Docker)
# Build:  docker build -t trust-backend .
# Run:    docker run --env-file .env -p 3000:3000 trust-backend
FROM node:22-alpine

WORKDIR /app
ENV NODE_ENV=production

# Faqat dependency fayllari — layer keshini saqlash uchun
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY src ./src

# Root bo'lmagan foydalanuvchi
USER node

EXPOSE 3000
CMD ["node", "src/index.js"]
