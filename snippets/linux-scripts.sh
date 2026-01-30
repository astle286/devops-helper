🐧 Linux Cheat Sheet

Command	Explanation
pwd	Print current working directory
ls -l	List files in long format (permissions, size, date)
cd /path	Change directory
cp file1 file2	Copy file
mv file1 file2	Move/rename file
rm file	Remove file (use -r for directories)
cat file	Show file contents
less file	View file contents page by page
grep "pattern" file	Search for text pattern in file
find /path -name "*.log"	Find files matching name pattern
chmod 755 file.sh	Change permissions (read/write/execute)
chown user:group file	Change file ownership
ps aux	Show running processes
kill -9 PID	Kill process by PID
df -h	Show disk usage in human-readable format
du -sh folder	Show folder size
tar -czvf archive.tar.gz folder	Compress folder into tarball
tar -xzvf archive.tar.gz	Extract tarball
curl URL	Fetch content from URL
wget URL	Download file from URL
scp file user@host:/path	Secure copy file to remote host
ssh user@host	Connect to remote host via SSH


#=====================================================================================================

📄 Template for .sh Scripts

bash
#!/bin/bash
# A template for shell scripts

# Exit immediately if a command fails
set -e

# Print each command before executing (for debugging)
set -x

# Variables
INPUT_FILE="input.txt"
OUTPUT_FILE="output.txt"

# Functions
say_hello() {
  echo "Hello, $1!"
}

# Main script logic
echo "Starting script..."
say_hello "Astle"

# Example command
cp "$INPUT_FILE" "$OUTPUT_FILE"

echo "Script finished successfully."

👉 Always start with #!/bin/bash and consider set -e (fail fast) and set -x (debug mode).


#=====================================================================================================


📝 Basic → Advanced Script Examples

1. Basic: Backup a File
bash
#!/bin/bash
# Backup a file with timestamp

FILE="app.py"
BACKUP="backup_$(date +%F_%T).py"

cp "$FILE" "$BACKUP"
echo "Backup created: $BACKUP"

#=====================================================================================================

2. Intermediate: Log Cleaner

bash
#!/bin/bash
# Delete old log files older than 7 days

LOG_DIR="/var/log/myapp"

find "$LOG_DIR" -name "*.log" -type f -mtime +7 -exec rm {} \;
echo "Old logs cleaned from $LOG_DIR"

#=====================================================================================================

3. Advanced: Deployment Script

bash
#!/bin/bash
# Deploy Python app with Docker

set -e

APP_NAME="myapp"
IMAGE="$APP_NAME:latest"

echo "Building Docker image..."
docker build -t "$IMAGE" .

echo "Stopping old container..."
docker rm -f "$APP_NAME" || true

echo "Starting new container..."
docker run -d --name "$APP_NAME" -p 8000:8000 "$IMAGE"

echo "Deployment complete!"


✅ Summary
#Cheat sheet → quick reference for everyday Linux commands.

#Template → reusable .sh structure with variables, functions, and safety flags.

#Scripts → show progression from simple backups → log management → automated deployments.