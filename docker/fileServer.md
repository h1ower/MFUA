## Файловый обменник



1. Запустить **simple-http-server** для раздачи файлов

в **Windows Powershell**
```shell
docker run -d `
 --name file-server `
 -p 8084:80 `
 -v "${PWD}:/srv" `
 halverneus/static-file-server:latest
```
![alt text](img/fileServer/2026-03-31_12-30-52.png)

в **Git-Bash/Linux/WSL 2.0/Mac**
```shell
docker run -d \
  --name file-server \
  -p 8084:80 \
  -v $(pwd):/srv \
  halverneus/static-file-server:latest
```
2. [Откройте: http://localhost:8084](http://localhost:8084)

![alt text](img/fileServer/2026-04-07_09-35-51.png)