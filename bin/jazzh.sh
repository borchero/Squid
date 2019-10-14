#!/bin/bash

DIR=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd $DIR/..

jazzy \
    --clean \
    --author "Oliver Borchert" \
    --author_url https://github.com/borchero \
    --github_url https://github.com/borchero/squid \
    --module Squid \
    --swift-build-tool spm \
    --build-tool-arguments -Xswiftc,-swift-version,-Xswiftc,5 \
    --documentation=examples/*.md \
    --theme fullwidth \
    --output docs
