ipconfig | grep -i "ipv4" | grep -Po "(?<=: )[\d.]+"
java -jar httpserver.jar -p 3000
:: python -m http.server 3000
