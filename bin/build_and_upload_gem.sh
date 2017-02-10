#!/bin/bash

gem build hf-transit-ruby.gemspec &&\
curl -F package=@`ls hf-transit-ruby-*.gem` https://4EigK-SfXrHqnwV3CzVA@push.fury.io/healthfinch/
