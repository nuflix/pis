# ===== 1) Install deps (cache-friendly) =====
FROM node:20-alpine AS deps
WORKDIR /app
# Kopiraj samo manifeste da bi cache radio
COPY package*.json ./
# Ako koristiš pnpm ili yarn, zamijeni naredbu ispod odgovarajućom
RUN npm ci

# ===== 2) Build (Next 15 / Turbopack OK) =====
FROM node:20-alpine AS builder
WORKDIR /app
# Prenesi node_modules iz deps stage-a
COPY --from=deps /app/node_modules ./node_modules
# Sada kopiraj ostatak koda
COPY . .
# (opciono) isključi strogi lint/TS na CI build-u
# ENV NEXT_TELEMETRY_DISABLED=1
# Ako si uveo ignore u next.config.js — super; u suprotnom build mora biti čist
RUN npm run build

# ===== 3) Runtime =====
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
# Fix za "TypeError: fetch failed" (SSL/DNS)
RUN apk add --no-cache ca-certificates
ENV NODE_OPTIONS=--dns-result-order=ipv4first

# --- (A) Učitaj .env fajl u kontejner (SAMO za lokal/dev!) ---
# Ako želiš da Next učita varijable iz .env fajla bez --env-file:
# COPY .env ./.env
# Napomena: Za produkciju nemoj peći taj fajl u sliku.

# App fajlovi
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/package*.json ./

# Samo production dependencije
RUN npm ci --omit=dev

EXPOSE 3000
CMD ["npx", "next", "start", "-p", "3000"]
