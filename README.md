# MonFire - Comandos de implantação

## VM 1

```bash
mkdir ~/monfire
cd ~/monfire
nano banco.sql                  
nano vm01_banco_site.sh
chmod +x vm01_banco_site.sh
./vm01_banco_site.sh
```

## VM 2

```bash
mkdir ~/monfire
cd ~/monfire
nano vm02_captura.sh
chmod +x vm02_captura.sh
./vm02_captura.sh 172.31.x.x    # troque pelo IP privado da VM 1
```

Na primeira execução, o Python secundário coletará o hostname, o IP, o MAC e
o sistema operacional da VM e solicitará o código de ativação.
As execuções seguintes reutilizarão o `MAQUINA_ID` salvo em
`/Monfire/python/agente.env`.
