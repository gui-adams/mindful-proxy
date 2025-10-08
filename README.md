# Hosts Redirector para Foco feito em Java
![Versão](https://img.shields.io/badge/versão-2.1-blue)
![Licença](https://img.shields.io/badge/licença-MIT-green)
![Tecnologias](https://img.shields.io/badge/tecnologias-Bash%20%7C%20Java%20%7C%20Systemd-lightgrey)

Uma solução de produtividade pessoal para redirecionar sites que causam distração, forçando um retorno consciente aos estudos e ao trabalho.


### Tabela de Conteúdos
1. [A Necessidade: O Desafio do Foco](#1-a-necessidade-o-desafio-do-foco)
2. [A Solução: Um "Guardião" de Produtividade](#2-a-solução-um-guardião-de-produtividade)
3. [Como Funciona: Arquitetura da Solução](#3-como-funciona-arquitetura-da-solução)
4. [Tecnologias Utilizadas](#4-tecnologias-utilizadas)
5. [Pré-requisitos](#5-pré-requisitos)
6. [Instalação](#6-instalação)
7. [Como Usar](#7-como-usar)
8. [Destaques do Projeto (Para Recrutadores)](#8-destaques-do-projeto-para-recrutadores)
9. [Possíveis Melhorias Futuras](#9-possíveis-melhorias-futuras)

---
### 1. A Necessidade: O Desafio do Foco

No mundo liquido, a maior batalha é pela nossa própria atenção. Como estudante e profissional, senti na pele a dificuldade de manter o foco em tarefas importantes enquanto um universo de distrações (redes sociais, portais de notícias, vídeos) está a apenas um clique de distância. Ferramentas de bloqueio existentes eram muitas vezes complexas, pagas ou baseadas em extensões de navegador que podiam ser facilmente desativadas.

Eu precisava de uma solução que fosse:
* **Profunda e robusta:** Atuando no nível do sistema operacional, não apenas no navegador.
* **Pessoal e customizável:** Permitindo que eu definisse facilmente minha própria lista de "ladrões de tempo".
* **Inspiradora, não punitiva:** Em vez de apenas mostrar uma tela de "bloqueado", a ferramenta deveria me motivar a voltar para o caminho certo.

Este projeto nasceu dessa necessidade pessoal de criar um ambiente digital que trabalhasse a meu favor, e não contra mim.

### 2. A Solução: Um "Guardião" de Produtividade

O **Hosts Redirector para Foco** é um conjunto de scripts que intercepta o acesso a sites pré-definidos e o redireciona para uma página local motivacional.

Quando o usuário tenta acessar um site da lista de bloqueio, em vez de ver o conteúdo que o distrairia, ele é apresentado a uma página com design e mensagens psicologicamente pensadas para incentivá-lo a retomar os estudos, sugerindo inclusive a Técnica Pomodoro.

O sistema é **automático**, **persistente entre reinicializações** e **extremamente leve**, rodando silenciosamente em segundo plano.

### 3. Como Funciona: Arquitetura da Solução

A solução é uma combinação inteligente de ferramentas de sistema e um pequeno servidor web:

1.  **Redirecionamento de DNS Local (`/etc/hosts`):** O script principal adiciona dinamicamente os domínios da sua lista de bloqueio ao arquivo `/etc/hosts`, apontando-os para o endereço local (`127.0.0.1`). Esta é a primeira linha de defesa, garantindo que qualquer requisição para esses sites seja resolvida localmente.

2.  **Servidor HTTPS Local (Java):** Hoje, quase todos os sites usam HTTPS. Um simples redirecionamento de host resultaria em erros de certificado no navegador. Para resolver isso, um servidor HTTPS mínimo, escrito em Java (sem a necessidade de frameworks), roda localmente na porta 443. Ele serve a página motivacional (`index.html`) com um certificado válido para os domínios bloqueados.

3.  **Geração Dinâmica de Certificados (OpenSSL):** O script utiliza OpenSSL para criar uma Autoridade Certificadora (CA) local e, em seguida, gerar um certificado de servidor que inclui **todos os domínios da lista de bloqueio** como *Subject Alternative Names* (SANs). Isso permite que um único certificado seja válido para `g1.globo.com`, `ge.globo.com`, etc., resolvendo o problema de segurança do HTTPS de forma elegante.

4.  **Automatização com `systemd`:** A verdadeira magia está na automação.
    * `https-focus.service`: Um serviço `systemd` que garante que o servidor Java inicie automaticamente com o sistema e seja reiniciado em caso de falha.
    * `hosts-redirector-reload.path`: Um "path unit" do `systemd` monitora o arquivo de texto da lista de bloqueio (`blocked-redirects.txt`). Ao detectar qualquer alteração (quando o arquivo é salvo), ele dispara um serviço `oneshot` que re-executa o script de regeneração, atualizando os certificados e o `/etc/hosts` de forma totalmente automática e instantânea.

### 4. Tecnologias Utilizadas

* **Shell Script (Bash):** Para orquestrar toda a instalação, configuração e automação.
* **Java:** Para o servidor HTTPS local, escolhido por sua robustez e por ser uma dependência comum em ambientes de desenvolvimento.
* **OpenSSL:** Para toda a gestão de certificados SSL/TLS, incluindo a criação de CA e certificados com SANs.
* **Systemd:** Para a daemonização do servidor e a automação baseada em eventos (monitoramento de arquivos).

### 5. Pré-requisitos

* Um sistema operacional baseado em Ubuntu ou Linux Mint (versão 20.04 ou superior).
* Acesso de administrador (`sudo`).

### 6. Instalação

O processo é totalmente automatizado por um único script.

```bash
# 1. Clone o repositório (ou apenas salve o script em um arquivo)
# git clone https://[seu-repositorio]/hosts-redirector-foco.git
# cd hosts-redirector-foco

# 2. Dê permissão de execução ao script
chmod +x setup.sh

# 3. Execute o script com sudo
sudo ./setup.sh
```
O script cuidará de instalar as dependências, criar a estrutura de arquivos, gerar os certificados e configurar os serviços para iniciar com o sistema.

### 7. Como Usar

A beleza da solução está na sua simplicidade de uso:

* **Para adicionar ou remover sites:** Basta editar o arquivo de texto com seu editor favorito:
    ```bash
    nano /opt/hosts-redirect/blocked-redirects.txt
    ```
    Adicione ou remova os domínios (um por linha) e salve o arquivo. As mudanças são aplicadas **automaticamente** em segundo plano.

* **Para verificar o status do servidor:**
    ```bash
    systemctl status https-focus.service
    ```

* **Para ver os logs:**
    ```bash
    tail -f /var/log/https-focus.log
    ```

### 8. Destaques do Projeto (Para Recrutadores)

* **Solução de um Problema Real:** Demonstra a capacidade de identificar uma necessidade pessoal e desenvolver uma solução técnica completa e prática.
* **Scripting Robusto e Idempotente:** O script de instalação foi projetado para ser executado múltiplas vezes sem causar erros, garantindo um estado final consistente.
* **Automação Inteligente:** O uso de `systemd.path` para automação baseada em eventos é uma abordagem moderna e eficiente, superior a `cron jobs` ou loops manuais, demonstrando conhecimento de ferramentas de sistema Linux.
* **Compreensão de Redes e Segurança:** A implementação do servidor HTTPS com geração dinâmica de certificados SAN mostra um entendimento profundo de como a web moderna funciona e como contornar desafios de segurança de forma legítima.
* **Arquitetura Simples e Eficiente:** A solução combina ferramentas de sistema poderosas de forma minimalista, sem a necessidade de frameworks pesados ou dependências complexas.

### 9. Possíveis Melhorias Futuras

* **Interface Gráfica Simples:** Desenvolver uma pequena aplicação (Web ou Desktop) para gerenciar a lista de bloqueio.
* **Suporte a Wildcards:** Permitir o bloqueio de subdomínios (ex: `*.globo.com`).
* **Agendamento:** Implementar a capacidade de ativar/desativar o bloqueio em horários específicos.
* **Portabilidade:** Adaptar o script para funcionar em outros sistemas, como macOS (usando `launchd`) e Windows (usando Agendador de Tarefas).
