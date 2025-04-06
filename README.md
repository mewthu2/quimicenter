Configuração e Execução com Docker
Siga estas etapas para configurar e executar o projeto localmente usando Docker:

1. Clone este repositório em sua máquina local:

```bash
  git clone https://github.com/seu-usuario/quimicenter.git
```
2. Navegue até o diretório do projeto:
  
```bash
  cd quimicenter
```

3. Construa a imagem Docker:

```bash
  docker build --network=host -t quimicenter .
```

4. Execute o contêiner Docker:

```bash
  docker-compose up --build -d
```

Acesse o painel administrativo em seu navegador da web:

```bash
  http://localhost:3000
```

# Licença
Este projeto é licenciado sob a MIT License.

