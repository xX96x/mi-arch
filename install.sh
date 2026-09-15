#!/bin/bash
set -e

echo "=========================================================="
echo "=== 1. PREPARATIVOS BÁSICOS Y USUARIO FABIARCH ==="
echo "=========================================================="
pacman -Sy --noconfirm
pacman -S --needed --noconfirm git base-devel sudo

if ! id "fabiarch" &>/dev/null; then
    useradd -m -G wheel -s /bin/bash fabiarch
    echo "Asigna la contraseña para fabiarch:"
    passwd fabiarch
fi

echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/10-wheel

echo "=========================================================="
echo "=== 2. INSTALANDO Y CONECTANDO CLOUDFLARE WARP ==="
echo "=========================================================="
sudo -u xX96x bash << 'EOF'
cd /home/fabiarch

if ! command -v paru &> /dev/null; then
    git clone https://aur.archlinux.org/paru-bin.git
    cd paru-bin
    makepkg -si --noconfirm
    cd .. && rm -rf paru-bin
fi

paru -S --needed --noconfirm cloudflare-warp-bin
EOF

systemctl enable --now warp-svc
sleep 2

warp-cli --accept-tos registration new || true
warp-cli --accept-tos connect

echo "Verificando conexión con Cloudflare Warp..."
sleep 3
warp-cli --accept-tos status

echo "=========================================================="
echo "=== 3. DESCARGANDO PLASMA Y RESTO DEL SISTEMA (VÍA WARP) =="
echo "=========================================================="
pacman -Syu --needed --noconfirm \
    plasma sddm networkmanager \
    dolphin firefox ark konsole \
    htop fastfetch btop

echo "=========================================================="
echo "=== 4. INSTALANDO RESTO DE PAQUETES (OCTOPI) ==="
echo "=========================================================="
sudo -u fabiarch bash << 'EOF'
paru -S --needed --noconfirm octopi
EOF

echo "=========================================================="
echo "=== 5. HABILITANDO SERVICIOS DEL SISTEMA ==="
echo "=========================================================="
systemctl enable NetworkManager
systemctl enable sddm

echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel

echo "=========================================================="
echo "¡LISTO! Tu sistema está replicado y corriendo con Warp."
echo "=========================================================="
