# syntax=docker/dockerfile:1

# =====================================================================
# Stage 1: install production dependencies only
# Anything that happens in this stage gets thrown away after the build,
# except for files we explicitly COPY --from=deps into the runtime stage.
# This keeps build tooling, dev dependencies, and the npm cache OUT of
# the final image.
# =====================================================================
FROM node:18-alpine AS deps
WORKDIR /app

# Copy only the dependency manifest files first.
# This lets Docker cache the npm install layer separately from source code.
# If you change index.js but not package.json, npm install is skipped on rebuild.
COPY app/package*.json ./

# `npm ci` is the deterministic version of `npm install` — it requires a
# package-lock.json and will refuse to run if the lockfile and package.json
# disagree. This is what you want in CI.
# `--omit=dev` skips devDependencies (jest, supertest) — we ran those in CI already.
RUN npm ci --omit=dev && npm cache clean --force

# =====================================================================
# Stage 2: runtime image
# Starts FROM a fresh node:18-alpine — none of the build artefacts
# (npm cache, lockfiles, build tools) are carried over.
# =====================================================================
FROM node:18-alpine AS runtime
WORKDIR /app

# Copy only the installed production node_modules from the deps stage.
# --chown=node:node makes the node user (uid 1000) the owner of these files.
COPY --from=deps --chown=node:node /app/node_modules ./node_modules

# Copy only the application source files we actually need at runtime.
# Notice: we don't COPY app/ . — that would include test files, lockfiles,
# and any junk in the directory. We copy explicitly.
COPY --chown=node:node app/index.js ./
COPY --chown=node:node app/package.json ./

# Run as a non-root user. node:18-alpine ships with a `node` user (uid 1000)
# built in. If anyone exploits a vulnerability in the app, they get the
# permissions of `node`, not root.
USER node

# Document the port. EXPOSE doesn't actually publish the port — it's just
# metadata for tools like docker-compose and orchestrators.
EXPOSE 3000

# Use the JSON/exec form (NOT shell form) so Node receives SIGTERM directly
# when the container is stopped, allowing graceful shutdown.
CMD ["node", "index.js"]
