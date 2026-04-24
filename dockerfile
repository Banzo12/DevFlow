# Use an official lightweight Node image
FROM node:18-alpine

# Set the working directory inside the container
WORKDIR /app

# Copy dependency files first (layer caching — explained below)
COPY app/package*.json ./

# Install dependencies
RUN npm install --production

# Copy the rest of the application code
COPY app/ .

# Expose the port the app runs on
EXPOSE 3000

# The command to run when the container starts
CMD ["node", "index.js"]