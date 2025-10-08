#!/usr/bin/env bash

set -euo pipefail

readonly BASE="/opt/hosts-redirect"
readonly SRC="$BASE/src"
readonly WEB="$BASE/web"
readonly CERTS="$BASE/certs"
readonly SECRET="$BASE/secret"
readonly LOCALCA="$BASE/local-ca"
readonly LIST="$BASE/blocked-redirects.txt"
readonly GEN_SCRIPT="$BASE/rebuild_from_list.sh"
readonly C_RESET='\033[0m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[0;33m'
readonly C_BLUE='\033[0;34m'
readonly C_RED='\033[0;31m'

log_info() {
  echo -e "${C_BLUE}[INFO]${C_RESET} $1"
}

log_success() {
  echo -e "${C_GREEN}[SUCCESS]${C_RESET} $1"
}

log_error() {
  echo -e "${C_RED}[ERROR]${C_RESET} $1" >&2
}

function check_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    log_error "Este script precisa ser executado como root. Use 'sudo'."
    exit 1
  fi
}

function install_dependencies() {
  log_info "Atualizando a lista de pacotes..."
  apt-get update -y
  log_info "Instalando dependências (default-jdk, openssl)..."
  apt-get install -y default-jdk ca-certificates openssl
}

function create_directories() {
  log_info "Criando estrutura de diretórios em $BASE..."
  mkdir -p "$SRC" "$WEB" "$CERTS" "$SECRET" "$LOCALCA"
  chmod 750 "$SECRET"
  chmod 700 "$LOCALCA"
}

function create_web_page() {
  log_info "Criando ou atualizando a página de bloqueio em $WEB/index.html..."
  tee "$WEB/index.html" >/dev/null <<'HTML'
<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>Foco nos Estudos</title>
  <style>
    :root {
      --cor-fundo: #0c1524;
      --cor-card: rgba(255, 255, 255, 0.08);
      --cor-texto-principal: #e6eef8;
      --cor-texto-secundario: #a8b9cf;
      --cor-destaque: #1cb5a9;
      --cor-botao-fundo: #0ea5a4;
      --cor-botao-texto: #012a2a;
      --cor-sombra: rgba(2, 6, 23, 0.7);
    }
    body {
      font-family: 'Inter', system-ui, 'Segoe UI', Roboto, Arial, sans-serif;
      background: var(--cor-fundo);
      color: var(--cor-texto-principal);
      display: flex;
      align-items: center;
      justify-content: center;
      height: 100vh;
      margin: 0;
      overflow: hidden;
      opacity: 0;
      animation: fadeIn 0.8s ease-out forwards;
    }
    .card {
      max-width: 740px;
      padding: 40px;
      border-radius: 18px;
      background: var(--cor-card);
      box-shadow: 0 12px 35px var(--cor-sombra);
      text-align: center;
      border: 1px solid rgba(255, 255, 255, 0.04);
      transform: scale(0.95);
      animation: scaleUp 0.8s ease-out forwards 0.2s;
    }
    h1 {
      margin: 0 0 16px;
      font-size: 38px;
      color: var(--cor-destaque);
      letter-spacing: -0.5px;
      font-weight: 800;
    }
    p {
      margin: 0 0 24px;
      font-size: 19px;
      color: var(--cor-texto-secundario);
      line-height: 1.6;
    }
    a.btn {
      display: inline-block;
      padding: 14px 24px;
      border-radius: 12px;
      background: var(--cor-botao-fundo);
      color: var(--cor-botao-texto);
      text-decoration: none;
      font-weight: 700;
      font-size: 18px;
      transition: all 0.3s ease;
      box-shadow: 0 6px 15px rgba(14, 165, 164, 0.4);
    }
    a.btn:hover {
      background: #098e8d;
      transform: translateY(-3px) scale(1.02);
      box-shadow: 0 9px 20px rgba(14, 165, 164, 0.6);
    }
    .small {
      margin-top: 24px;
      font-size: 15px;
      color: var(--cor-texto-secundario);
      opacity: 0.7;
    }
    @keyframes fadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }
    @keyframes scaleUp {
      from { transform: scale(0.95); opacity: 0; }
      to { transform: scale(1); opacity: 1; }
    }
    @keyframes pulse {
        0% { transform: scale(1); }
        50% { transform: scale(1.01); }
        100% { transform: scale(1); }
    }
    .btn {
        animation: pulse 2s infinite ease-in-out 1s;
    }
    body.exit-animation {
        animation: fadeOutZoom 0.6s ease-in forwards;
    }
    @keyframes fadeOutZoom {
        from { opacity: 1; transform: scale(1); }
        to { opacity: 0; transform: scale(0.8); }
    }
  </style>
</head>
<body>
  <div class="card">
    <h1><span style="color: #fce205;">Pare.</span> <span style="color: var(--cor-destaque);">Foque.</span> <span style="color: #1a71ff;">Estude.</span></h1>
    <p>Você acessou um site que pode desviar seu foco. Este é um lembrete para <br> retornar ao seu objetivo principal e **conquistar seus estudos**.</p>
    <a class="btn" href="https://questoes.grancursosonline.com.br/" target="_blank" rel="noopener">
      &#x1F4DA; Ir para as Questões Agora &#x27A1;
    </a>
    <div class="small">
      Lembre-se da Técnica Pomodoro: 25 min foco intenso + 5 min pausa. <br>
      Sua jornada de aprendizado te espera!
    </div>
  </div>
  <script>
    document.querySelector('.btn').addEventListener('click', function(event) {
        event.preventDefault();
        const button = this;
        document.body.classList.add('exit-animation');
        setTimeout(function() {
            window.open(button.href, button.target);
        }, 500);
    });
  </script>
</body>
</html>
HTML
}

function create_block_list() {
  if [ ! -f "$LIST" ]; then
    log_info "Criando lista de bloqueio padrão em $LIST..."
    tee "$LIST" >/dev/null <<'EOF'
# -----------------
# REDES SOCIAIS E VÍDEOS
# -----------------
youtube.com
www.youtube.com
m.youtube.com
facebook.com
www.facebook.com
instagram.com
www.instagram.com
twitter.com
www.twitter.com
x.com
www.x.com
tiktok.com
www.tiktok.com
reddit.com
www.reddit.com
linkedin.com
www.linkedin.com
pinterest.com
www.pinterest.com
br.pinterest.com
twitch.tv
www.twitch.tv
kwai.com
www.kwai.com

# -----------------
# NOTÍCIAS NACIONAIS
# -----------------
g1.globo.com
www.g1.globo.com
oglobo.globo.com
www.oglobo.globo.com
valor.globo.com
uol.com.br
www.uol.com.br
noticias.uol.com.br
folha.uol.com.br
www.folha.uol.com.br
terra.com.br
www.terra.com.br
r7.com
www.r7.com
noticias.r7.com
estadao.com.br
www.estadao.com.br
metropoles.com
www.metropoles.com
cnnbrasil.com.br
www.cnnbrasil.com.br
poder360.com.br
www.poder360.com.br
jovempan.com.br
noticias.jovempan.com.br
band.uol.com.br/noticias
veja.abril.com.br
exame.com
cartacapital.com.br
oantagonista.com
brasil247.com

# -----------------
# ESPORTES
# -----------------
ge.globo.com
www.ge.globo.com
globoesporte.globo.com
esporte.uol.com.br
esportes.terra.com.br
esportes.r7.com
espn.com.br
www.espn.com.br
lance.com.br
www.lance.com.br
placar.com.br
gazetaesportiva.com
bandsports.com.br
esporte.band.uol.com.br

# -----------------
# AGREGADORES E OUTROS
# -----------------
br.noticias.yahoo.com
news.google.com

EOF
  fi
}

function create_java_server() {
  log_info "Criando o código-fonte do servidor Java..."
  tee "$SRC/HttpsFocusServer.java" >/dev/null <<'JAVA'
import com.sun.net.httpserver.*;
import javax.net.ssl.*;
import java.io.*;
import java.net.InetSocketAddress;
import java.nio.file.*;
import java.security.*;

public class HttpsFocusServer {
    public static void main(String[] args) {
        try {
            if (args.length < 3) {
                System.err.println("Uso: HttpsFocusServer <PORTA> <CAMINHO_P12> <SENHA> [WEB_ROOT]");
                System.exit(1);
            }
            int port = Integer.parseInt(args[0]);
            Path p12Path = Paths.get(args[1]);
            char[] password = args[2].toCharArray();
            Path webRoot = Paths.get(args.length == 4 ? args[3] : "/opt/hosts-redirect/web");

            if (!Files.exists(p12Path)) throw new FileNotFoundException("Arquivo P12 não encontrado: " + p12Path);
            if (!Files.isDirectory(webRoot)) throw new FileNotFoundException("Diretório web_root não encontrado: " + webRoot);
            
            KeyStore ks = KeyStore.getInstance("PKCS12");
            try (InputStream is = Files.newInputStream(p12Path)) { ks.load(is, password); }
            
            KeyManagerFactory kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());
            kmf.init(ks, password);
            
            SSLContext sslContext = SSLContext.getInstance("TLS");
            sslContext.init(kmf.getKeyManagers(), null, new SecureRandom());

            HttpsServer server = HttpsServer.create(new InetSocketAddress("::", port), 0);
            server.setHttpsConfigurator(new HttpsConfigurator(sslContext));
            server.createContext("/", exchange -> {
                try {
                    byte[] response = Files.readAllBytes(webRoot.resolve("index.html"));
                    exchange.getResponseHeaders().add("Content-Type", "text/html; charset=utf-8");
                    exchange.getResponseHeaders().add("Cache-Control", "no-store");
                    exchange.sendResponseHeaders(200, response.length);
                    try (OutputStream os = exchange.getResponseBody()) { os.write(response); }
                } catch (IOException e) {
                    byte[] errorResponse = ("Erro interno: " + e.getMessage()).getBytes();
                    exchange.sendResponseHeaders(500, errorResponse.length);
                    try (OutputStream os = exchange.getResponseBody()) { os.write(errorResponse); }
                } finally {
                    exchange.close();
                }
            });
            server.setExecutor(null);
            System.out.println("Servidor HTTPS de Foco iniciado na porta " + port);
            server.start();
        } catch (Exception e) {
            System.err.println("Falha fatal ao iniciar o servidor: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
JAVA
}

function create_rebuild_script() {
  log_info "Criando o script de regeneração de hosts e certificados..."
  tee "$GEN_SCRIPT" >/dev/null <<'BASH'
#!/usr/bin/env bash
set -euo pipefail

BASE="/opt/hosts-redirect"
LIST="$BASE/blocked-redirects.txt"
LOCALCA="$BASE/local-ca"
OPENSSL_CNF="$LOCALCA/openssl.cnf"
CERTS="$BASE/certs"
SECRET="$BASE/secret"
P12="$CERTS/server.p12"
PASSFILE="$SECRET/p12.pass"
HOSTS_BEGIN="# BEGIN HOSTS-REDIRECTOR (managed by script)"
HOSTS_END="# END HOSTS-REDIRECTOR"

echo "==== Iniciando Regeneração de Hosts/Certificados ===="
mkdir -p "$LOCALCA" "$CERTS" "$SECRET"; chmod 750 "$SECRET"; chmod 700 "$LOCALCA"

if [ ! -s "$LIST" ]; then
  echo "  [WARN] Lista de bloqueio $LIST está vazia. Limpando /etc/hosts."
  if grep -qF "$HOSTS_BEGIN" /etc/hosts; then
      sed -i.bak "/$HOSTS_BEGIN/,/$HOSTS_END/d" /etc/hosts
  fi
  exit 0
fi

DOMAINS=()
while IFS= read -r line; do
  domain=$(echo "$line" | sed 's/#.*//; s/^\s*//; s/\s*$//')
  [ -n "$domain" ] && DOMAINS+=("$domain")
done < "$LIST"

if [ ${#DOMAINS[@]} -eq 0 ]; then
    echo "  [WARN] Nenhum domínio válido encontrado. Nada a fazer."
    exit 0
fi
echo "  [INFO] Encontrados ${#DOMAINS[@]} domínios para processar."

echo "  [INFO] Gerando configuração OpenSSL..."
cat > "$OPENSSL_CNF" <<EOF
[ req ]
distinguished_name  = dn
req_extensions      = v3_req
[ dn ]
CN = Localhost Redirector
[ v3_req ]
subjectAltName = @alt_names
[ alt_names ]
EOF
i=1
for d in "${DOMAINS[@]}"; do
  echo "DNS.$i = $d" >> "$OPENSSL_CNF"
  i=$((i+1))
done

if [ ! -f "$LOCALCA/localCA.key" ]; then
  echo "  [INFO] Criando nova Autoridade Certificadora (CA) local..."
  openssl genrsa -out "$LOCALCA/localCA.key" 4096
  openssl req -x509 -new -nodes -key "$LOCALCA/localCA.key" -sha256 -days 3650 \
    -out "$LOCALCA/localCA.crt" -subj "/C=BR/O=LocalCA/CN=Local Root CA"
  echo "  [INFO] Instalando CA no sistema..."
  cp "$LOCALCA/localCA.crt" /usr/local/share/ca-certificates/
  update-ca-certificates
fi

echo "  [INFO] Gerando novo certificado de servidor para os domínios..."
openssl genrsa -out "$CERTS/server.key" 2048
openssl req -new -key "$CERTS/server.key" -out "$CERTS/server.csr" -config "$OPENSSL_CNF" -subj "/CN=Localhost Redirector"
openssl x509 -req -in "$CERTS/server.csr" -CA "$LOCALCA/localCA.crt" -CAkey "$LOCALCA/localCA.key" \
  -CAcreateserial -out "$CERTS/server.crt" -days 730 -sha256 -extfile "$OPENSSL_CNF" -extensions v3_req

if [ ! -f "$PASSFILE" ]; then
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24 > "$PASSFILE"
  chmod 600 "$PASSFILE"
fi
openssl pkcs12 -export -inkey "$CERTS/server.key" -in "$CERTS/server.crt" \
  -name hosts-redirector -out "$P12" -passout file:"$PASSFILE"

echo "  [INFO] Atualizando /etc/hosts..."
sed -i.bak "/$HOSTS_BEGIN/,/$HOSTS_END/d" /etc/hosts
{
  echo "$HOSTS_BEGIN"
  for d in "${DOMAINS[@]}"; do
    echo "127.0.0.1 $d"; echo "::1       $d";
  done
  echo "$HOSTS_END"
} >> /etc/hosts
chmod 644 /etc/hosts

echo "  [INFO] Recompilando o servidor Java (se necessário)..."
javac "$BASE/src/HttpsFocusServer.java"
echo "  [INFO] Sinalizando para o systemd reiniciar o serviço..."
systemctl restart https-focus.service
echo "==== Regeneração Concluída ===="
BASH
  chmod +x "$GEN_SCRIPT"
}

function create_systemd_units() {
  log_info "Criando e configurando os serviços do systemd..."
  
  tee "/etc/systemd/system/https-focus.service" >/dev/null <<SERVICE
[Unit]
Description=HTTPS Focus Server (Java)
After=network-online.target
[Service]
Type=simple
ExecStart=/usr/bin/java -cp $SRC HttpsFocusServer 443 $CERTS/server.p12 "\$(cat $SECRET/p12.pass)" $WEB
Restart=on-failure; RestartSec=5; User=root
StandardOutput=append:/var/log/https-focus.log
StandardError=append:/var/log/https-focus.log
[Install]
WantedBy=multi-user.target
SERVICE

  tee "/etc/systemd/system/hosts-redirector-reload.service" >/dev/null <<RELOADSVC
[Unit]
Description=Rebuild certificate/hosts from block list
[Service]
Type=oneshot; ExecStart=$GEN_SCRIPT
RELOADSVC

  tee "/etc/systemd/system/hosts-redirector-reload.path" >/dev/null <<RELOADPATH
[Unit]
Description=Watch block list for changes
[Path]
PathChanged=$LIST; Unit=hosts-redirector-reload.service
[Install]
WantedBy=multi-user.target
RELOADPATH
}

function run_first_build_and_enable() {
  log_info "Compilando o servidor Java pela primeira vez..."
  javac "$SRC/HttpsFocusServer.java"

  log_info "Executando a primeira geração de hosts e certificados..."
  "$GEN_SCRIPT"
  
  log_info "Habilitando e iniciando os serviços..."
  systemctl daemon-reload
  systemctl enable --now https-focus.service
  systemctl enable --now hosts-redirector-reload.path
}

main() {
  check_root
  
  install_dependencies
  create_directories
  create_web_page
  create_block_list
  create_java_server
  create_rebuild_script
  create_systemd_units
  
  run_first_build_and_enable
  
  echo
  log_success "=== INSTALAÇÃO CONCLUÍDA ==="
  echo "O sistema de foco está ativo e iniciará com o sistema."
  echo
  echo -e "Para editar os sites bloqueados, modifique o arquivo:"
  echo -e "  ${C_YELLOW}$LIST${C_RESET}"
  echo
  echo "As mudanças serão aplicadas automaticamente ao salvar o arquivo."
  echo "Para verificar o status, use: ${C_YELLOW}systemctl status https-focus.service${C_RESET}"
  echo "Logs do servidor estão em: ${C_YELLOW}/var/log/https-focus.log${C_RESET}"
}

main "$@"