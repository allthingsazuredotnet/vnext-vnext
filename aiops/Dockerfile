# Use an official Python runtime as a parent image
FROM python:3.10.0-alpine

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file into the container first to leverage Docker cache
COPY requirements.txt .

# Install Python dependencies
# Ensure gunicorn is listed in your requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of your application code
COPY . .

# Define the port the application will run on.
# Your aiops.py script uses os.environ.get("PORT", 5000).
# This ENV PORT will be used by your app if set.
ENV PORT=5000

# Expose the port the app runs on
EXPOSE 5000

# Command to run your application using Gunicorn
# This assumes your Flask application instance is named 'app' in 'aiops.py'
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "aiops:app"]