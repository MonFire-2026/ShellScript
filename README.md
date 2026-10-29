# MonFire - Comandos de implantação

## VM 1

```bash
mkdir ~/monfire
cd ~/monfire
nano banco.sql                  
nano vm1_banco_site.sh          
chmod +x vm1_banco_site.sh
./vm1_banco_site.sh
```

## VM 2

```bash
mkdir ~/monfire
cd ~/monfire
nano vm2_captura_java.sh        
chmod +x vm2_captura_java.sh
./vm2_captura_java.sh 172.31.x.x    # troque pelo IP privado da VM 1
```