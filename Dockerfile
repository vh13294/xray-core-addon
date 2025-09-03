ARG BUILD_FROM
FROM $BUILD_FROM

# Install dependencies for downloading and unzipping
RUN apk add --no-cache curl unzip jq

# Copy the run script into the container
COPY run.sh /
RUN chmod a+x /run.sh

# Run the script when the container starts
CMD [ "/run.sh" ]
