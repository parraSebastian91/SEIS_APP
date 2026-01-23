#!/bin/bash
set -e

# Crear bases de datos para Kong y Konga
psql -v ON_ERROR_STOP=1 --username "kong" --dbname "postgres" <<-EOSQL
    CREATE DATABASE kong;
    CREATE DATABASE konga;
EOSQL

echo "✅ Bases de datos 'kong' y 'konga' creadas exitosamente"