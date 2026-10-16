# vendor

Сюда кладётся дистрибутив КриптоПро CSP для сборки rootfs (в git не хранится — проприетарный):

- `cprocsp-5.0.13003-linux-arm64_deb.tgz` — КриптоПро CSP 5.0 R3 для Linux ARM64, deb,
  ветка `CSP_5_0r3t_ngate` (в архиве `linux-arm64.ini`: `version=5.0.13003`).
  Скачивается из центра загрузки cryptopro.ru (нужна учётная запись).
  SHA-256: `65777a978677139636999e8aebd61fae7172dcdd147597b8140afe418a5d703d`.

Другой путь к архиву: `CSP_TGZ=... ./build-rootfs.sh`.
