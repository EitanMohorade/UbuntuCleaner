# Política de severidad

## OK
La operación terminó correctamente.

Ejemplos:
- caché limpiada
- logs depurados
- reparación completada

---

## SKIP
La tarea fue omitida intencionalmente.

No representa un problema.

Ejemplos:
- Docker no instalado
- directorio inexistente
- feature deshabilitada
- filesystem incompatible

---

## WARN
La operación tuvo un problema tolerable.

El sistema sigue funcionando.

Ejemplos:
- recurso inaccesible
- limpieza parcial
- permisos insuficientes
- daemon apagado

---

## TIMEOUT
La operación excedió el tiempo permitido.

Puede indicar:
- I/O bloqueado
- disco lento
- mount colgado
- servicio congelado

Debe investigarse.

---

## ERROR
La operación crítica falló.

Puede afectar:
- integridad
- consistencia
- mantenimiento
- reparación del sistema

Ejemplos:
- apt roto
- fsck falló
- corrupción detectada
