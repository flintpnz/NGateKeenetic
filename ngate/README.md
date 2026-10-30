# ngate: КриптоПро NGate на Keenetic/Netcraze → OpkgTun0

Аналог whvpn для NGate. Интерфейс **NGATE** (`OpkgTun0`) виден в веб-интерфейсе и включается
переключателем; NGate работает в Debian-chroot и поднимает туннель на устройстве прошивки
`opkgtun0`. Вход: логин + пароль + TOTP (Мультифактор), код генерируется на каждый (пере)коннект.
Маршруты (только нужные адреса, без маршрута по умолчанию) ставит ngatetun. DNS — в AdGuard Home.
Интерфейс создаётся с `ip global auto` — иначе NGATE не виден в вебе; `auto` ставит его в конец
приоритетов, default остаётся через провайдера.

Проверено: Docker linux/arm64 с имитацией прошивки (ndmc + RCI), тестовый шлюз ng-test.cryptopro.ru;
на роутере проверен формат RCI `{"parse": ...}` (Netcraze Ultra NC-1812, KeeneticOS 5.2 Beta 0).

## Как устроено

| whvpn (OpenVPN) | ngate |
|---|---|
| `--dev opkgtun0` | `libngatetun-shim.so` (LD_PRELOAD для ngatetun): `TUNSETIFF tun0` → `opkgtun0`, без `IFF_TUN_EXCL` |
| `--ifconfig-noexec` + `up.sh` | `/usr/local/sbin/ip` в chroot: `addr add` → RCI `interface OpkgTun0 ip address`, MTU → `ip mtu` |
| `down.sh` | тот же `ip`: `addr del` → заглушка `192.0.2.1/32`; `link down` пропускается |
| маршруты ставит OpenVPN | маршруты ставит ngatetun (`ip route` проходит как есть) |
| `whvpn.sh` — супервизор | `ngate-keeper` в chroot: проверка узла за туннелем, переподключение, пауза до 15 мин при ошибках входа |
| OTP в auth-файле | `ngate-session.exp` отвечает на запросы OTP кодом из `ngate-totp` (oathtool) |

## Файлы

```
/opt/etc/ngate/            (Entware)            /opt/debian/  (chroot)
  ngate.env    настройки                          etc/ngate-keeper.conf              TOTP, проверка, OpkgTun
  ngate.sh     start|stop|restart|status|log|enter opt/cprongate/console_client.ini   url, логин, пароль
  hook.sh  -> /opt/etc/ndm/iflayerchanged.d/50-ngate.sh   usr/local/bin/ngate-keeper, ngate-session.exp, ngate-totp
  init.sh  -> /opt/etc/init.d/S99ngate             usr/local/sbin/ip
  install.sh   установка/обновление; remove        usr/local/lib/libngatetun-shim.so
  chroot/      файлы для chroot
  ngate-rootfs.tar.gz  Debian+CSP+NGate (удаляется после распаковки)
```

Во время работы `/run`, `/tmp`, `/var/log` chroot — в RAM (tmpfs).

## Свежий клон репозитория

В git нет трёх файлов, без которых пакет на роутер не поставить:

| Файл | Почему нет в git | Как получить |
|---|---|---|
| `vendor/cprocsp-5.0.13003-linux-arm64_deb.tgz` | проприетарный дистрибутив КриптоПро | скачать с cryptopro.ru, см. `vendor/README.md` |
| `ngate-rootfs.tar.gz` | результат сборки, ~70 МБ | `./build-rootfs.sh` |
| `chroot/usr/local/lib/libngatetun-shim.so` | результат сборки | `./build-rootfs.sh` |

Поэтому после `git clone`: положить архив CSP в `vendor/` → `./build-rootfs.sh` → дальше по разделу
«Установка». Без `.so` туннель не поднимется: ngatetun создаст свой `tun0` вместо `opkgtun0`.

## Установка

0. **Место:** rootfs ≈ 260 МБ в распакованном виде — `/opt` должен быть на USB-диске (`df -h /opt`).
1. На Mac (один раз, нужен Docker): `./build-rootfs.sh` → `ngate-rootfs.tar.gz` и `libngatetun-shim.so`.
   Исходники сборки:
   - `vendor/cprocsp-5.0.13003-linux-arm64_deb.tgz` — КриптоПро CSP 5.0 R3 для ARM64
     (ветка `CSP_5_0r3t_ngate`; скачан из центра загрузки cryptopro.ru);
   - `certs/root/*.cer` (CryptoPro GOST Root CA → mRoot) и `certs/ca/*.cer` (CryptoPro TLS CA → mCA);
   - NGate — из репозитория `https://ng-client.cryptopro.ru/repository/debian/arm64`.

   Другой архив CSP или каталог сертификатов: `CSP_TGZ=... CERTS=... ./build-rootfs.sh`.
2. Скопировать пакет на роутер (`vendor/`, `certs/`, `test/` там не нужны — всё уже внутри rootfs):
   ```sh
   tar -C ~/work/my/git/NGateKeenetic --exclude ngate/test --exclude ngate/vendor --exclude ngate/certs -cf - ngate \
     | ssh -p 222 root@192.168.1.1 'mkdir -p /opt/etc && tar -C /opt/etc -xf -'
   ```
   Обновить скрипты на уже установленном роутере (rootfs повторно не передаётся):
   ```sh
   tar -C ~/work/my/git/NGateKeenetic --exclude ngate/test --exclude ngate/vendor --exclude ngate/certs \
       --exclude ngate/ngate-rootfs.tar.gz -cf - ngate \
     | ssh -p 222 root@192.168.1.1 'tar -C /opt/etc -xf -'
   ```
3. На роутере (Entware): при желании вписать `CSP_LICENSE` в `/opt/etc/ngate/ngate.env`, затем
   `sh /opt/etc/ngate/install.sh`.
4. Заполнить (chmod 600 уже стоит):
   - `/opt/debian/opt/cprongate/console_client.ini` — `username=` (без @domain), `password="..."` (обязательно в двойных кавычках: без них запятая в пароле ломает чтение, клиент ждёт ввода с клавиатуры);
   - `/opt/debian/etc/ngate-keeper.conf` — `NG_TOTP_SECRET` (base32 из QR Мультифактора).
5. Включить **NGATE** в веб-интерфейсе. Проверка: `/opt/etc/ngate/ngate.sh status`, лог: `ngate.sh log`.
6. Направить нужное через NGATE (маршруты от шлюза ставятся сами; для LAN-клиентов NAT делает
   прошивка — `security-level public`).

## Использование

- Переключатель NGATE в веб-интерфейсе.
- `/opt/etc/ngate/ngate.sh status | log | restart | enter` (`enter` — оболочка в chroot).
- Журналы (RAM): `/opt/debian/var/log/ngate-keeper.log`, `ngate-client.log`, `ngate-ip.log`,
  `/opt/debian/opt/cprongate/ngate_tun_service.log`.

## Поведение

- Обрыв (клиент вышел или `NG_CHECK_HOST:NG_CHECK_PORT` не отвечает 3 раза подряд) → переподключение
  со свежим OTP через 15 с, при повторных неудачах пауза растёт до 15 мин.
- OTP отвергнут 3 раза подряд / шлюз требует смены пароля → пауза 15 мин (чтобы не заблокировать учётку).
- Клиент не прочитал логин или пароль из `console_client.ini` (запрос `Please enter password`) → сеанс завершается с кодом 7, в логе причина, пауза 15 мин. Пароль на шлюз при этом не уходит.
- Один OTP дважды не отправляется; если шлюз спрашивает код второй раз в том же 30-секундном окне,
  ответ уйдёт в следующем окне.
- Выкл. в веб-интерфейсе → клиент завершает сеанс, маршруты сняты, на интерфейсе заглушка.

## Снять

```sh
sh /opt/etc/ngate/install.sh remove
ndmc -c 'no interface OpkgTun0' && ndmc -c 'system configuration save'   # если нужен и интерфейс
rm -rf /opt/debian                                                        # если нужен и chroot
```

## Тесты (Mac, Docker)

```sh
# перехватчик + обёртка ip на тестовом шлюзе (образ ngate-dev: ngate-diag + gcc)
docker run --rm --platform linux/arm64 --cap-add NET_ADMIN --device /dev/net/tun \
  -v "$PWD":/k:ro ngate-dev bash /k/test/run-test.sh
# весь пакет в имитации роутера: install.sh, hook вкл/выкл, обрыв и переподключение
docker run --rm --platform linux/arm64 --privileged -v "$PWD":/pkg:ro router-sim \
  bash /pkg/test/router-sim/run.sh
```

## Заметки

- Хранить пароль и TOTP-секрет на роутере = фактически один фактор; согласуйте с ИБ.
- `opkg upgrade` не затрагивает chroot. Обновить NGate: `ngate.sh enter`, затем `apt update && apt upgrade`.
  Если пакет cprongate-tun снова запустит ngatetun без перехватчика, keeper это заметит и перезапустит его.
