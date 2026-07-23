# Use the stable production image as the base
FROM mayanedms/mayanedms:latest

# Switch to root user to copy and overwrite system paths
USER root

# The official image stores the operational source code here
WORKDIR /opt/astro-edms

# Copy your local repository changes into the container's source tree
COPY --chown=mayan:mayan . .

# Re-run the python installations locally to compile any package updates
RUN /opt/mayan-edms/venv/bin/pip install --no-cache-dir -e

# Revert back to the secure non-root user that Mayan runs on
USER mayan

# Keep the official startup entries intact
ENTRYPOINT ["entrypoint.sh"]
CMD ["mayan"]

