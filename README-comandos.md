# 1. Detener todo
docker-compose --profile admin-tools down

# 2. Eliminar volumen de Kong
docker volume rm kong_postgres_data

# 3. Levantar con PostgreSQL 9.6
docker-compose up -d kong-db
sleep 30

# 4. Crear base de datos de Konga manualmente
docker exec -it kong_postgres psql -U kong -d kong -c "CREATE DATABASE konga;"

# 5. Preparar Konga
docker-compose up konga-prepare
sleep 10

# 6. Levantar Kong
docker-compose up -d kong-migration
sleep 20
docker-compose up -d kong
sleep 20

# 7. Levantar Konga
docker-compose --profile admin-tools up -d konga

# 8. Ver logs
docker-compose logs -f konga

docker-compose -f docker-compose.yml build --no-cache auth-service   
docker-compose -f docker-compose.yml up -d --force-recreate auth-service    