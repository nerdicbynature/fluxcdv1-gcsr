FROM fluxcd/flux:1.21.1
COPY --from=gcr.io/google.com/cloudsdktool/cloud-sdk:326.0.0 /usr/lib/google-cloud-sdk /opt/google-cloud-sdk
COPY files /
