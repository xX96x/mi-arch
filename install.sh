#!/bin/bash
set -e

# Asegurar que se ejecuta como root
if [ "$EUID" -ne 0 ]; then
  echo "[-] Por favor ejecuta este script como root."
  exit 1
fi

echo "=========================================================="
echo "=== 1. PREPARATIVOS BÁSICOS Y USUARIO FABIARCH ==="
echo "=========================================================="
pacman -Sy --noconfirm
pacman -S --needed --noconfirm git base-devel sudo

# Crear usuario si no existe, o verificar grupo si ya existe
if ! id "fabiarch" &>/dev/null; then
    useradd -m -G wheel -s /bin/bash fabiarch
    echo "Asigna la contraseña para fabiarch:"
    passwd fabiarch
else
    echo "[+] El usuario fabiarch ya existe. Asegurando permisos..."
    usermod -aG wheel -s /bin/bash fabiarch
fi

# Darle permisos de sudo temporalmente para compilar sin interrupciones
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/10-wheel

echo "=========================================================="
echo "=== 2. INSTALANDO Y CONECTANDO CLOUDFLARE WARP ==="
echo "=========================================================="
sudo -u fabiarch bash << 'EOF'
cd /home/fabiarch

# Instalar paru solo si no existe
if ! command -v paru &> /dev/null; then
    echo "[+] Compilando paru..."
    rm -rf paru-bin
    git clone https://aur.archlinux.org/paru-bin.git
    cd paru-bin
    makepkg -si --noconfirm
    cd .. && rm -rf paru-bin
else
    echo "[+] Paru ya está instalado."
fi

# Instalar Cloudflare Warp si no está instalado
if ! command -v warp-cli &> /dev/null; then
    echo "[+] Instalando cloudflare-warp-bin..."
    paru -S --needed --noconfirm cloudflare-warp-bin
else
    echo "[+] Cloudflare Warp ya está instalado."
fi
EOF

# Iniciar servicio si no está corriendo
systemctl enable --now warp-svc || true
sleep 2

# Registrar y conectar solo si no está conectado aún
echo "[+] Conectando a Cloudflare Warp..."
warp-cli --accept-tos registration new 2>/dev/null || true
warp-cli --accept-tos connect 2>/dev/null || true

sleep 3
warp-cli --accept-tos status || true

echo "=========================================================="
echo "=== 3. INSTALANDO PLASMA Y APLICACIONES (VÍA WARP) ==="
echo "=========================================================="
# El flag --needed omite lo que ya se descargó previamente
pacman -Syu --needed --noconfirm \
    plasma sddm networkmanager \
    dolphin firefox ark konsole \
    htop fastfetch btop

echo "=========================================================="
echo "=== 4. INSTALANDO PAQUETES DE USUARIO ==="
echo "=========================================================="
sudo -u fabiarch bash << 'EOF'
paru -S --needed --noconfirm octopi
EOF

echo "=========================================================="
echo "=== 5. FINALIZANDO Y HABILITANDO SERVICIOS ==="
echo "=========================================================="
systemctl enable NetworkManager || true
systemctl enable sddm || true

# Restaurar permisos sudo seguros (pidiendo contraseña)
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel

# Asegurar permisos correctos en el home de fabiarch
chown -R fabiarch:fabiarch /home/fabiarch

echo "=========================================================="
echo "¡LISTO! Tu sistema está replicado con éxito."
echo "=========================================================="
