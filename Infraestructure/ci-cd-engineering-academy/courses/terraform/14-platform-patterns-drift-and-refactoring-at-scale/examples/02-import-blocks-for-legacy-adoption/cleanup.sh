#!/usr/bin/env bash
set -eu

rm -rf /tmp/tf14-ex02-legacy
rm -f  generated.tf adopted.tf
rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup

echo "cleaned legacy dir and local TF state in cwd"
