### 🛠️ Habilitar Wake-on-LAN en Proxmox VE
 ### ⚠️ Si su servidor estás detrás de un proxy corporativo, antes de descargar el script tiene que exportar las variables para que pueda salir a internet. Si lo usas con autenticación utilice el siguiente formato:
**http://user:password@proxy.enterprise.cu:3128**

***Si lo anterior no es su escenario, vaya directo al punto #1***

``` sh
export http_proxy="http://proxy.cualquiera.cu:3128/"
export https_proxy="http://proxy.cualquiera.cu:3128/"
```

#### ✒️ También tienes que correr los comandos siguientes para que "git" funcione correctamente:
``` sh
echo "[http]" >> ~/.gitconfig
echo "    proxy = http://proxy.cualquiera.cu:3128/" >> ~/.gitconfig
```
### 🔽 1.  Descargar el script

1- Clone el repositorio para descargar el script en su servidor, copiando y pegando la línea de abajo en su terminal de preferencia:
``` sh
   git clone https://github.com/ygironb/proxmox_wake-on-lan.git
```
  
2- Dale permiso de ejecución desde la consola:
``` sh
   chmod +x proxmox_wake-on-lan.sh
```
  
3- Correr el script:
``` sh
  ./proxmox_wake-on-lan.sh
```


💡 **Nota: No olvide habilitar la opción en la BIOS según la configuración de la motherboard que usted utiliza**
