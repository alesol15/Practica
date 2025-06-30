# Verifica que se pasaron exactamente 2 argumentos
if [ $# -ne 2 ]; then
    echo "Error: Two arguments are required"
    exit 1
fi

writefile=$1
writestr=$2

# Crea el directorio si no existe
mkdir -p "$(dirname "$writefile")"

# Intenta escribir en el archivo
echo "$writestr" > "$writefile"

# Verifica si se pudo escribir correctamente
if [ $? -ne 0 ]; then
    echo "Error: is not possible to create/write in: '$writefile'"
    exit 1
fi

exit 0
