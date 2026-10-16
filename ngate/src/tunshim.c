/*
 * LD_PRELOAD-перехватчик для ngatetun: вместо создания собственного tunN
 * подключается к уже существующему устройству прошивки (opkgtun0).
 *
 * NGATE_TUN_DEV   имя устройства прошивки (по умолчанию opkgtun0)
 * NGATE_TUN_MAP   файл, куда пишется "<имя, которое просил ngatetun> <реальное имя>"
 *                 (по умолчанию /run/ngate-tun.map) — его читает обёртка ip
 * NGATE_TUN_LOG   журнал перехватчика (по умолчанию не ведётся)
 *
 * Сборка: gcc -shared -fPIC -O2 -o libngatetun-shim.so tunshim.c -ldl
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <net/if.h>
#include <linux/if_tun.h>
#include <sys/ioctl.h>

static int (*real_ioctl)(int, unsigned long, ...);

static void shim_log(const char *fmt, ...)
{
    const char *path = getenv("NGATE_TUN_LOG");
    if (!path || !*path)
        return;
    FILE *f = fopen(path, "a");
    if (!f)
        return;
    va_list ap;
    va_start(ap, fmt);
    vfprintf(f, fmt, ap);
    va_end(ap);
    fputc('\n', f);
    fclose(f);
}

static void write_map(const char *asked, const char *real)
{
    const char *path = getenv("NGATE_TUN_MAP");
    FILE *f = fopen(path && *path ? path : "/run/ngate-tun.map", "w");
    if (!f)
        return;
    fprintf(f, "%s %s\n", asked, real);
    fclose(f);
}

int ioctl(int fd, unsigned long request, ...)
{
    va_list ap;
    va_start(ap, request);
    void *arg = va_arg(ap, void *);
    va_end(ap);

    if (!real_ioctl)
        real_ioctl = (int (*)(int, unsigned long, ...))dlsym(RTLD_NEXT, "ioctl");

    if (request != TUNSETIFF || !arg) {
        int rc = real_ioctl(fd, request, arg);
        if (getenv("NGATE_TUN_TRACE"))
            shim_log("ioctl fd=%d req=0x%lx rc=%d", fd, request, rc);
        return rc;
    }

    struct ifreq *ifr = arg;
    const char *dev = getenv("NGATE_TUN_DEV");
    if (!dev || !*dev)
        dev = "opkgtun0";

    char asked[IFNAMSIZ + 1] = {0};
    strncpy(asked, ifr->ifr_name, IFNAMSIZ);
    short flags = ifr->ifr_flags;

    /* Устройство прошивки уже существует: эксклюзивное открытие вернёт EBUSY. */
    ifr->ifr_flags &= ~IFF_TUN_EXCL;
    memset(ifr->ifr_name, 0, IFNAMSIZ);
    strncpy(ifr->ifr_name, dev, IFNAMSIZ - 1);

    int rc = real_ioctl(fd, request, arg);
    shim_log("TUNSETIFF asked=%s flags=0x%04x -> dev=%s flags=0x%04x rc=%d",
             asked, (unsigned short)flags, ifr->ifr_name,
             (unsigned short)ifr->ifr_flags, rc);

    if (rc == 0) {
        write_map(asked, ifr->ifr_name);
        /* ngatetun дальше работает с тем именем, которое просил */
        memset(ifr->ifr_name, 0, IFNAMSIZ);
        strncpy(ifr->ifr_name, asked, IFNAMSIZ - 1);
    }
    return rc;
}
