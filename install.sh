#!/bin/bash
set -e

# Asegurar que se ejecuta como root
if [ "$EUID" -ne 0 ]; then
  echo "[-] Por favor ejecuta este script como root."
  exit 1
fi

echo "=========================================================="
echo "=== 1. USUARIO FABIARCH Y PERMISOS ==="
echo "=========================================================="
pacman -Sy --noconfirm
pacman -S --needed --noconfirm curl tar sudo git

if ! id "fabiarch" &>/dev/null; then
    useradd -m -G wheel -s /bin/bash fabiarch
    echo "Asigna la contraseña para fabiarch:"
    passwd fabiarch
else
    echo "[+] El usuario fabiarch ya existe."
    usermod -aG wheel -s /bin/bash fabiarch
fi

echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/10-wheel

echo "=========================================================="
echo "=== 2. AÑADIENDO REPO CACHYOS E INSTALANDO PARU ==="
echo "=========================================================="
# Instalar repo de CachyOS si no está agregado
if ! grep -q "cachyos" /etc/pacman.conf; then
    echo "[+] Añadiendo repositorio oficial de CachyOS..."
    curl -s https://mirror.cachyos.org/cachyos-repo.tar.xz -o /tmp/cachyos-repo.tar.xz
    tar -xf /tmp/cachyos-repo.tar.xz -C /tmp/
    (cd /tmp/cachyos-repo && ./cachyos-repo.sh)
    rm -rf /tmp/cachyos-repo*
else
    echo "[+] Repositorio CachyOS ya configurado."
fi

# Instalar paru y octopi DIRECTOS desde el repositorio binario (¡en segundos!)
pacman -Sy --needed --noconfirm paru octopi

echo "=========================================================="
echo "=== 3. INSTALANDO Y CONECTANDO CLOUDFLARE WARP ==="
echo "=========================================================="
if ! command -v warp-cli &> /dev/null; then
    echo "[+] Instalando cloudflare-warp-bin con paru..."
    sudo -u fabiarch paru -S --needed --noconfirm cloudflare-warp-bin
else
    echo "[+] Cloudflare Warp ya está instalado."
fi

systemctl enable --now warp-svc || true
sleep 2

echo "[+] Conectando a Cloudflare Warp..."
warp-cli --accept-tos registration new 2>/dev/null || true
warp-cli --accept-tos connect 2>/dev/null || true

sleep 3
warp-cli --accept-tos status || true

echo "=========================================================="
echo "=== 4. INSTALANDO PLASMA Y RESTO DEL SISTEMA (VÍA WARP) ==="
echo "=========================================================="
pacman -Syu --needed --noconfirm \
    plasma sddm networkmanager \
    dolphin firefox ark konsole \
    htop fastfetch btop

echo "=========================================================="
echo "=== 5. SERVICIOS Y SEGURIDAD ==="
echo "=========================================================="
systemctl enable NetworkManager || true
systemctl enable sddm || true

# Restaurar permisos normales de sudo (con contraseña)
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel

# Permisos del directorio personal
chown -R fabiarch:fabiarch /home/fabiarch

echo "=========================================================="
echo "¡LISTO! Sistema replicado a velocidad CachyOS y protegido por Warp."
echo "=========================================================="
