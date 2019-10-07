#!/bin/bash

jazzy \
    --clean \
    --author "Oliver Borchert" \
    --author_url https://github.com/borchero \
    --github_url https://github.com/borchero/squid \
    --module Squid \
    --swift-build-tool spm \
    --build-tool-arguments -Xswiftc,-swift-version,-Xswiftc,5 \
    --output docs

