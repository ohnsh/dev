FREETSA_CERT=/Volumes/Media/lib/timestamp/cacert.pem

freetsa_stamp() {
  local file=$1
  openssl ts -query -data "$file" \
    -no_nonce -sha512 -cert -out "$file.tsq" && \
  curl -sH "Content-Type: application/timestamp-query" \
    --data-binary "@$file.tsq" \
    "https://freetsa.org/tsr" > "$file.tsr"
}

freetsa_verify() {
  local file=$1
  openssl ts -verify \
    -in "$file.tsr" -queryfile "$file.tsq" \
    -CAfile "$FREETSA_CERT"
}
