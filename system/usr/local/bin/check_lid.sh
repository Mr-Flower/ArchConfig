#!/bin/bash
if grep -q "closed" /proc/acpi/button/lid/*/state; then
    exit 1  # Lid chiuso
else
    exit 0  # Lid aperto
fi
