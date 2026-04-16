mc alias set myminio http://localhost:9000 minioadmin minioadmin123

mc anonymous set download myminio/seis-app/public

cat <<EOF > cors.json
{
    "CORSRules": [
        {
            "AllowedOrigins": ["*"],
            "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
            "AllowedHeaders": ["*"],
            "ExposeHeaders": ["ETag"]
        }
    ]
}
EOF

mc cors set myminio/seis-app cors.json