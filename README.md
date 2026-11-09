# Tic Tac Toe

Game Tic Tac Toe klasik yang dibuat dengan [LÖVE](https://love2d.org/). Mainkan bersama teman dalam mode dua pemain, atau tantang komputer dengan tiga pilihan tingkat kesulitan.

## Fitur

- Papan 3×3 dengan animasi tanda X/O dan garis penanda kemenangan.
- Mode **2 Pemain** dan **Vs Komputer**.
- Tiga tingkat kesulitan komputer:
  - **Mudah** — memilih langkah secara acak.
  - **Sedang** — memilih langkah terbaik pada sekitar 65% giliran, selain itu acak.
  - **Sulit** — menggunakan Minimax dengan alpha-beta pruning untuk memilih langkah optimal.
- Papan skor terpisah untuk masing-masing mode; skor bertahan saat ronde diulang dan dapat dihapus kapan saja.
- Kontrol menggunakan mouse maupun keyboard.

## Persyaratan

- [LÖVE (Love2D)](https://love2d.org/) terpasang.

Proyek ini tidak memerlukan pustaka tambahan. Jendela permainan berukuran 600×820 piksel dan tidak dapat diubah ukurannya.

## Menjalankan

Jalankan folder proyek dengan LÖVE:

```sh
love .
```

Di Windows, perintahnya dapat dijalankan melalui Command Prompt atau PowerShell jika `love.exe` tersedia di `PATH`. Alternatifnya, buka file `tictactoe.love` dengan aplikasi LÖVE.

## Kontrol

| Aksi | Mouse | Keyboard |
|---|---|---|
| Memilih kotak | Klik kotak di papan | Tombol `1`–`9` atau numpad |
| Memulai ronde baru | Klik papan setelah ronde selesai | `R`; setelah ronde selesai juga `Enter`, `Space`, atau `Enter` numpad |
| Mengganti mode | Pilih tombol mode | `M` |
| Mengganti tingkat kesulitan | Pilih tombol level (mode Vs Komputer) | `L` |
| Menghapus skor mode aktif | — | `C` |
| Keluar | — | `Esc` |

Susunan tombol `1`–`9` mengikuti posisi papan dari kiri ke kanan, baris demi baris:

```text
1 2 3
4 5 6
7 8 9
```

## Struktur proyek

- `main.lua` — logika permainan, AI, rendering, dan input.
- `tictactoe.love` — paket permainan LÖVE yang disertakan.
