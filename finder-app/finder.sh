
# Verifica que se pasaron exactamente 2 argumentos
if [ $# -ne 2 ]; then
    echo "Error: the parameters are not correct"
    exit 1
fi

filesdir=$1
searchstr=$2

# Verifica que el primer argumento sea un directorio válido
if [ ! -d "$filesdir" ]; then
    echo "Error: '$filesdir' is not a valid directory"
    exit 1
fi

# Cuenta archivos
file_count=$(find "$filesdir" -type f | wc -l)

# Cuenta líneas que contienen la cadena
match_count=$(grep -r "$searchstr" "$filesdir" | wc -l)

echo "The number of files are $file_count and the number of matching lines are $match_count"
exit 0
