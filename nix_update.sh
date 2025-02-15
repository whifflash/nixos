#!/usr/bin/env bash

sudo nixos-rebuild switch --upgrade --flake .#$(hostname)
