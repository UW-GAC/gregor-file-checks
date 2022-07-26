FROM uwgac/anvildatamodels:0.1.0

RUN cd /usr/local && \
    git clone https://github.com/UW-GAC/gregor-file-checks.git
