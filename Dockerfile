FROM returntocorp/semgrep:1.56.0

USER root

RUN apk update
RUN apk add --no-cache ruby ruby-dev ruby-json jq bash grep git wget

# To add gh cli
RUN wget https://github.com/cli/cli/releases/download/v2.4.0/gh_2.4.0_linux_amd64.tar.gz -O /tmp/gh.tar.gz && \
    tar -xvf /tmp/gh.tar.gz -C /tmp && \
    mv /tmp/gh_*_linux_amd64/bin/gh /usr/local/bin/gh && \
    rm -rf /tmp/gh_*

COPY parser.rb /parser.rb
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
