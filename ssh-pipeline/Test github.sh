#!/bin/bash

echo Checking key...
ssh -T git@github.com -o StrictHostKeyChecking=no;
